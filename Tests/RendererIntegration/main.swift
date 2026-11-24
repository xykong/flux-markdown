import AppKit
import WebKit

// Unbuffered, so a timeout report shows which cases already passed.
setvbuf(stdout, nil, _IONBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
final class RendererIntegration: NSObject, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var focusWindow: NSWindow?
    private var previousApplication: NSRunningApplication?
    private let mathPasteboard = NSPasteboard.withUniqueName()
    private let mathCopyBridge = BlockCopyBridge()
    private let boundaryCopyBridge = BlockCopyBridge()
    private var imageScheme: LocalSchemeHandler!
    private var boundaryRequestCount = 0
    private var sourceCopyRequestCount = 0
    private let sourceCopyBridge = BlockCopyBridge()
    private var failNextMathCopy = false
    private let diagramExport=DiagramExportService()
    private let diagramPasteboard=NSPasteboard.withUniqueName()
    private var started = false
    private var index = 0
    private var feedbackEvents: [[String: Any]] = []
    private var cases: [(String, String)] = [
        ("Reading workflow compact diagram toolbar geometry", """
        for(const context of ['app','quicklook']) {
          await window.renderMarkdown('```mermaid\\nflowchart LR; A-->B;\\n```\\n\\n'+svgMarkdown,{context,uiLanguage:'zh',imageData:svgImageData});
          const hosts=Array.from(document.querySelectorAll('.mermaid,.svg-image-diagram'));
          if(hosts.length<2)throw new Error('Missing diagram types');
          const check=(host,label)=>{
            const tools=host.querySelector('.diagram-tools'), menu=tools.querySelector('details');
            for(const expanded of [false,true]) {
              menu.open=expanded;
              for(const control of tools.querySelectorAll(':scope > button, :scope > details > summary')) {
                const rect=control.getBoundingClientRect();
                if(Math.abs(rect.height-28)>1)throw new Error(label+' toolbar control height '+rect.height+' expanded '+expanded);
                if(!control.matches('[data-diagram-zoom=reset]') && Math.abs(rect.width-28)>1)throw new Error(label+' icon is not square: '+rect.width);
              }
            }
            menu.open=false;
          };
          for(const theme of ['light','dark'])for(const zoom of [0.5,1,1.5,3]) {
            window.updateTheme(theme);window.setZoomLevel(zoom);
            hosts.forEach(host=>check(host,context+' '+theme+' '+zoom));
          }
          hosts[0].querySelector('[data-diagram-action=focus]').click();check(hosts[0],'focused');window.closeDiagramFocus();
        }
        window.setZoomLevel(1);return true;
        """),
        ("Reading workflow interrupted opening restores saved position", """
        const text=Array.from({length:30},(_,i)=>'Distinct paragraph '+i+' '+('Reading. '.repeat(40))).join('\\n\\n')+'\\n\\n## Saved Position\\n\\n'+('After the anchor.\\n\\n'.repeat(40))+'\\n\\n```mermaid\\nflowchart LR; A-->B;\\n```';
        const options={context:'app',uiLanguage:'en',documentId:'interrupted-open',readingState:{id:'saved-position',hash:'',index:30,top:120,scrollY:900,zoom:1.5}};
        const first=window.renderMarkdown(text,options);
        await window.renderMarkdown(text,options);await first;
        const top=viewportRect(document.getElementById('saved-position')).top;
        if(Math.abs(top-120)>3 || window.captureReadingState().zoom!==1.5)throw new Error('unfinished opening replaced the durable reading position: '+top);
        window.setZoomLevel(1);return true;
        """),
        ("native production clipboard byte boundaries", """
        const limit=4*1024*1024, received=[];
        const original=window.blockCopyResult;
        window.blockCopyResult=(id,generation,success)=>received.push({id,generation,success});
        let sequence=1000;
        try {
          for(const prefix of ['', '中文 😀\\t\\n']) for(const delta of [-1,0,1]) {
            const text=prefix+'x'.repeat(limit+delta-new TextEncoder().encode(prefix).length);
            if(new TextEncoder().encode(text).length!==limit+delta)throw new Error('Invalid fixture byte length');
            const id=String(sequence++), before=received.length;
            window.webkit.messageHandlers.blockCopy.postMessage({id,generation:'boundary',text});
            if(delta<=0) {
              const deadline=Date.now()+5000;
              while(received.length===before && Date.now()<deadline)await new Promise(r=>setTimeout(r,10));
              const ack=received[before];
              if(!ack || ack.id!==id || ack.generation!=='boundary' || ack.success!==true)throw new Error('Missing or wrong native acknowledgement');
            } else {
              await new Promise(r=>setTimeout(r,200));
              if(received.length!==before)throw new Error('Oversized request acknowledged');
            }
          }
          const before=received.length;
          window.webkit.messageHandlers.blockCopy.postMessage({id:String(sequence),generation:'stale-boundary',text:'STALE'});
          await new Promise(r=>setTimeout(r,200));
          if(received.length!==before)throw new Error('Stale request acknowledged');
          return true;
        } finally {window.blockCopyResult=original;}
        """),
        ("production image count boundaries", """
        for(const context of ['app','quicklook']) for(const count of [31,32,33]) {
          const markdown=Array.from({length:count},(_,i)=>`![Image ${i+1}](boundary-${i+1}.png)`).join('\\n\\n')+'\\n\\nIMAGE-BOUNDARY-END';
          await window.renderMarkdown(markdown,{context,baseUrl:imageBase});
          const images=[...document.querySelectorAll('#markdown-preview img')];
          const deadline=Date.now()+5000;
          while(images.some(i=>!i.complete) && Date.now()<deadline)await new Promise(r=>setTimeout(r,20));
          if(images.length!==count)throw new Error('Image element count changed');
          for(let i=0;i<count;i++) {
            const expected=i<32?1:0;
            if(images[i].naturalWidth!==expected || images[i].naturalHeight!==expected)throw new Error(JSON.stringify({context,count,index:i+1,width:images[i].naturalWidth,height:images[i].naturalHeight}));
          }
          if(!document.getElementById('markdown-preview').textContent.includes('IMAGE-BOUNDARY-END'))throw new Error('Final content lost');
        }
        return true;
        """),
        ("production image alias and invalid decode partitions", """
        for(const context of ['app','quicklook']) {
          await window.renderMarkdown('![one](pixel.png)\\n\\n![repeat](pixel.png)\\n\\n![alias](./pixel.png)\\n\\n![invalid](invalid.png)\\n\\n![missing](missing.png)\\n\\nPARTITION-END',{context,baseUrl:imageBase});
          const images=[...document.querySelectorAll('#markdown-preview img')], deadline=Date.now()+5000;
          while(images.some(i=>!i.complete) && Date.now()<deadline)await new Promise(r=>setTimeout(r,20));
          if(images.length!==5 || images.slice(0,3).some(i=>i.naturalWidth!==1 || i.naturalHeight!==1) || images.slice(3).some(i=>i.naturalWidth!==0))throw new Error('Alias/decode partition mismatch');
          if(!document.getElementById('markdown-preview').textContent.includes('PARTITION-END'))throw new Error('Partition tail lost');
        }
        return true;
        """),
        ("Source view blank lines in native selection and Quick Look copy", """
        const root=document.getElementById('markdown-preview');
        const received=[];
        const original=window.blockCopyResult;
        window.blockCopyResult=(id,generation,success)=>{
          original(id,generation,success);
          received.push(success);
        };
        try {
          window.setFeedbackGeneration('source-copy-probe');
          for(const source of ['alpha\\n\\nbeta','alpha\\n\\n\\nbeta']) {
            window.renderSource(source,'light',undefined,{context:'quicklook',selectionCopy:true});
            const rows=root.querySelectorAll('.source-diff-line');
            const first=rows[0].firstChild, last=rows[rows.length-1].firstChild;
            const range=document.createRange();range.setStart(first,1);range.setEnd(last,3);
            const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
            const expected=source.slice(1,-1);
            if(selection.toString()!==expected)throw new Error('WebKit native selection changed blank lines');
            if(rows[0].getBoundingClientRect().height!==rows[1].getBoundingClientRect().height)
              throw new Error('Blank row height changed');
            for(const format of ['plain','markdown']) {
              const count=received.length;
              window.copyQuickLookSelection(format);
              for(const deadline=Date.now()+2000;received.length===count && Date.now()<deadline;)
                await new Promise(resolve=>setTimeout(resolve,20));
              if(received[count]!==true)throw new Error('Native clipboard rejected '+format);
            }
          }
          // Native Cmd+C in Source View should write plain text only (no HTML/RTF)
          // so rich-text targets keep adjacent non-empty lines and blank lines intact.
          const richSource='## Title\\n\\n### 1.1 Heading\\nParagraph below heading\\n- item 1\\n- item 2\\n';
          for(const opts of [{context:'quicklook',selectionCopy:true},{context:'app'}]) {
            window.renderSource(richSource,'light',undefined,opts);
            const rows=root.querySelectorAll('.source-diff-line');
            if(rows[0].tagName!=='DIV')throw new Error('Source line should be a block DIV');
            const selectAllRange=document.createRange();
            selectAllRange.selectNodeContents(document.body);
            const selection=getSelection();selection.removeAllRanges();selection.addRange(selectAllRange);
            const dt=new DataTransfer();
            const ev=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:dt});
            document.dispatchEvent(ev);
            if(!ev.defaultPrevented)throw new Error('Source copy event was not intercepted for '+opts.context);
            if(dt.types.length!==1 || dt.types[0]!=='text/plain')throw new Error('Unexpected clipboard types: '+dt.types.join(','));
            if(dt.getData('text/plain')!==richSource)throw new Error('Plain text payload mismatch for '+opts.context);
          }
          function copyAllSource() {
            const range=document.createRange();range.selectNodeContents(document.body);
            const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
            const clipboard=new DataTransfer();
            const event=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:clipboard});
            document.dispatchEvent(event);
            return {event,clipboard};
          }
          for(const previous of [undefined,'first\\r\\nremoved\\r\\nlast\\r\\n']) {
            window.renderSource('first\\r\\nlast\\r\\n','light',previous,{context:'app'});
            for(let cleared=0;cleared<2;cleared++) {
              const {event,clipboard}=copyAllSource();
              if(!event.defaultPrevented || clipboard.getData('text/plain')!=='first\\nlast\\n')
                throw new Error('Source copy changed CRLF or diff line structure: '+JSON.stringify(clipboard.getData('text/plain')));
              window.clearDiffMarks();
            }
          }
          window.renderSource('name\\tvalue\\nfoo\\tbar\\n','light',undefined,{context:'app',format:'tsv',isTruncated:true});
          const tsvCopy=copyAllSource();
          if(!root.querySelector('.tsv-truncated') || tsvCopy.event.defaultPrevented || tsvCopy.clipboard.types.length)
            throw new Error('Truncated TSV copy should use the native selection');
          window.renderSource(richSource,'light',undefined,{context:'quicklook',selectionCopy:true});
          copyAllSource();
          // Search input inside Source View must not be intercepted.
          const input=document.createElement('input');
          input.value='find-me';
          document.body.append(input);
          try {
            input.focus();
            const dtInput=new DataTransfer();
            const evInput=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:dtInput});
            input.dispatchEvent(evInput);
            if(evInput.defaultPrevented)throw new Error('Source copy intercepted search input');
          } finally {input.remove();}
          // Rendered view keeps native rich-text copy by default, and writes exact Markdown source
          // (preserving 0-blank-line and multi-blank-line boundaries) when defaultCopyFormat is 'markdown'.
          const previewSource='### 1.1 Heading\\nParagraph below heading\\n\\n\\nAfter two blank lines';
          await window.renderMarkdown(previewSource,{context:'quicklook',selectionCopy:true,defaultCopyFormat:'rich-text'});
          const renderedRange=document.createRange();
          renderedRange.selectNodeContents(root);
          const selRendered=getSelection();selRendered.removeAllRanges();selRendered.addRange(renderedRange);
          const dtRendered=new DataTransfer();
          const evRendered=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:dtRendered});
          document.dispatchEvent(evRendered);
          if(evRendered.defaultPrevented)throw new Error('Rendered view rich-text copy should not be intercepted');
          window.setDefaultCopyFormat('markdown');
          const dtMd=new DataTransfer();
          const evMd=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:dtMd});
          document.dispatchEvent(evMd);
          if(!evMd.defaultPrevented)throw new Error('Rendered view markdown copy was not intercepted');
          if(dtMd.types.length!==1 || dtMd.types[0]!=='text/plain')throw new Error('Unexpected markdown copy types: '+dtMd.types.join(','));
          if(dtMd.getData('text/plain')!==previewSource)throw new Error('Markdown copy mismatch: '+JSON.stringify(dtMd.getData('text/plain')));
          window.setDefaultCopyFormat('rich-text');
        } finally {window.blockCopyResult=original;}
        return true;
        """),
        ("Quick Look selection scope and lifecycle", """
        const root=document.getElementById('markdown-preview');
        const settle=()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
        for(const context of ['app','finder','quicklook']) {
          await window.renderMarkdown('hello **world**',{context,selectionCopy:true,showCopyButtons:true});
          const text=root.querySelector('strong').firstChild;
          const range=document.createRange();range.selectNodeContents(text);
          const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
          await settle();
          let tools=root.querySelector('.selection-copy-tools');
          if(context==='quicklook') {
            // selectionchange arrives as its own task, so on a slow runner the toolbar
            // update can land after the two frames above.
            for(const deadline=Date.now()+2000;(!tools || tools.hidden) && Date.now()<deadline;tools=root.querySelector('.selection-copy-tools'))await settle();
            if(!tools || tools.hidden || [...tools.querySelectorAll('button')].map(b=>b.textContent).join()!=='⧉,MD')throw new Error('Selection copy buttons missing');
            if(new DOMParser().parseFromString(window.exportHTML(),'text/html').querySelector('.selection-copy-tools'))throw new Error('Selection tools leaked into export');
          } else if(tools)throw new Error('Selection controller enabled outside Quick Look');
        }
        window.renderSource('**source**','light',undefined,{context:'quicklook',selectionCopy:true,showCopyButtons:true});
        if(!root.querySelector('.selection-copy-tools'))throw new Error('Source-first controller missing');
        window.renderSource('app source','light');
        if(root.querySelector('.selection-copy-tools'))throw new Error('Source inherited selection capability');
        return true;
        """),
        ("Reading workflow focus navigation and refresh", """
        const text=Array.from({length:45},(_,i)=>'## Chapter '+i+'\\n\\nDistinct paragraph for chapter '+i+'. '+('Readable text. '.repeat(25))).join('\\n\\n')+'\\n\\n```mermaid\\nflowchart LR; A[Inspect]-->B[Diagram];\\n```';
        await window.renderMarkdown(text,{context:'app',documentId:'workflow-a',uiLanguage:'en'});
        const root=document.getElementById('markdown-preview');
        root.querySelectorAll('p')[20].scrollIntoView({block:'center'});
        window.setZoomLevel(1.5);
        const before=window.captureReadingState();
        const media=window.matchMedia;window.matchMedia=()=>({matches:true});
        document.querySelector('#toc-container a[href="#chapter-35"]').click();
        if(window.captureReadingState().hash===before.hash)throw new Error('TOC did not jump');
        window.navigateReadingHistory(-1);
        const back=window.captureReadingState();
        if(back.hash!==before.hash || Math.abs(back.top-before.top)>3 || back.zoom!==before.zoom)throw new Error('Back lost reading state');
        window.navigateReadingHistory(1);window.matchMedia=media;
        root.querySelectorAll('p')[20].scrollIntoView({block:'center'});
        const saved=window.captureReadingState();
        await window.renderMarkdown('Inserted paragraph.\\n\\n'+text,{context:'app',documentId:'workflow-a',uiLanguage:'en'});
        const restored=window.captureReadingState();
        if(saved.hash!==restored.hash || Math.abs(saved.top-restored.top)>3)throw new Error('semantic refresh did not preserve paragraph');
        const host=document.querySelector('.mermaid');host.scrollIntoView({block:'center'});
        const origin=window.captureReadingState(), originalSVG=host.querySelector('svg');
        host.querySelector('[data-diagram-action=focus]').click();
        const dialog=document.getElementById('diagram-focus'),stage=dialog?.querySelector('.focus-stage');
        if(!dialog || !stage.contains(originalSVG) || root.contains(host))throw new Error('focus did not move the original drawing');
        const box=viewportRect(originalSVG);
        if(box.width>stage.clientWidth+2 || box.height>stage.clientHeight+2)throw new Error('fit-to-window overflow');
        dialog.querySelector('.focus-toolbar button:nth-child(2)').click();
        if(host.querySelector('[data-diagram-zoom=reset]').textContent!=='100%')throw new Error('focus 100 percent failed');
        if(window.stepReadingZoom(0.1)!==null || host.querySelector('[data-diagram-zoom=reset]').textContent!=='125%')throw new Error('focus keyboard zoom targeted document');
        window.stepReadingZoom(null);
        if(root.style.getPropertyValue('zoom')!=='1.5')throw new Error('focus zoom changed background document');
        dialog.querySelector('.focus-toolbar button:last-child').click();
        if(document.getElementById('diagram-focus') || !root.contains(originalSVG))throw new Error('focus close lost diagram');
        const closed=window.captureReadingState();
        if(closed.hash!==origin.hash || Math.abs(closed.top-origin.top)>3)throw new Error('focus close lost reading location');
        host.querySelector('[data-diagram-action=focus]').click();
        const exported=window.exportHTML();
        const exportedDocument=new DOMParser().parseFromString(exported,'text/html');
        if(document.getElementById('diagram-focus') || !exportedDocument.querySelector('.mermaid svg') || exportedDocument.querySelector('.diagram-tools'))throw new Error('document export lost focused diagram or included tools');
        window.setZoomLevel(1);return true;
        """),
        ("Reading workflow diagram native artifacts", """
        window.__workflowResults=[];
        window.setFeedbackGeneration('workflow-probe');
        await window.renderMarkdown('## Export\\n\\n```mermaid\\nflowchart LR; A[Standalone diagram]-->B[Native PNG and SVG];\\n```',{context:'app',uiLanguage:'en'});
        await window.waitForExportReady();
        const tools=document.querySelector('.mermaid .diagram-tools');
        for(const action of ['copy','png','svg']) {
          tools.querySelector('[data-diagram-action='+action+']').click();
          const end=performance.now()+12000, expected=action==='copy'?'copied':'saved';
          while(window.__workflowResults.length<(['copy','png','svg'].indexOf(action)+1) && performance.now()<end)await new Promise(r=>setTimeout(r,50));
          if(window.__workflowResults.at(-1)?.status!==expected)throw new Error('native artifact missing acknowledgement: '+action);
        }
        return true;
        """),
        ("Reading zoom Mermaid pinch and fixed controls", """
        for(const context of ['app','quicklook']) {
          window.setZoomLevel(1);
          const graph='flowchart LR\\n'+Array.from({length:12},(_,i)=>'N'+i+'[Wide node '+i+']'+(i?'':'')).join('-->');
          await window.renderMarkdown(('Leading reading text.\\n\\n'.repeat(30))+'## Diagrams\\n\\nBody text stays stable.\\n\\n```mermaid\\n'+graph+'\\n```\\n\\n```mermaid\\nflowchart TB; A-->B-->C-->D-->E-->F-->G-->H-->I-->J-->K-->L-->M-->N-->O-->P-->Q-->R;\\n```'+('\\n\\nTrailing reading text.'.repeat(30)),{context});
          await window.waitForExportReady();
          const root=document.getElementById('markdown-preview'), hosts=root.querySelectorAll('.mermaid');
          const svg=hosts[0].querySelector('svg'), other=hosts[1].querySelector('svg');
          const viewport=hosts[0].querySelector('.mermaid-viewport'), tools=hosts[0].querySelector('.diagram-tools');
          svg.scrollIntoView({block:'center'});
          const base=viewportRect(svg), otherWidth=viewportRect(other).width;
          const toolWidth=tools.getBoundingClientRect().width, button=tools.querySelector('button').getBoundingClientRect();
          const bodySize=getComputedStyle(root).fontSize;
          const point={x:viewport.getBoundingClientRect().left+120,y:Math.max(90,base.top+base.height/2),gesture:901};
          const result=window.applyPinchZoom(1,0,point);
          if(result!==null)throw new Error('diagram pinch was routed to body');
          const fx=(point.x-base.left)/base.width, fy=(point.y-base.top)/base.height;
          for(let i=1;i<=40;i++) {
            window.applyPinchZoom(1,i/40,{...point,x:i===40?innerWidth-5:point.x,finished:i===40});
            const rect=viewportRect(svg);
            if(Math.abs(rect.left+rect.width*fx-point.x)>3 || Math.abs(rect.top+rect.height*fy-point.y)>3)throw new Error('diagram anchor drifted during pinch');
          }
          if(Math.abs(viewportRect(svg).width/base.width-2)>0.03)throw new Error('pinch did not scale Mermaid drawing');
          if(viewportRect(other).width!==otherWidth || getComputedStyle(root).fontSize!==bodySize || root.style.getPropertyValue('zoom')!=='1')throw new Error('diagram pinch changed body or other drawing');
          if(Math.abs(tools.querySelector('button').getBoundingClientRect().width-button.width)>1)throw new Error('diagram pinch scaled controls');
          if(viewport.scrollWidth<=viewport.clientWidth)throw new Error('zoomed diagram lacks local scrolling');
          tools.querySelector('[data-diagram-zoom=in]').click();
          if(Math.abs(viewportRect(svg).width/base.width-2.5)>0.04)throw new Error('button and gesture scales diverged');
          const beforeGlobal=viewportRect(svg).width;
          window.setZoomLevel(2);
          await new Promise(r=>setTimeout(r,80));
          if(Math.abs(viewportRect(svg).width/beforeGlobal-2)>0.05)throw new Error('automatic fit cancelled global diagram zoom '+JSON.stringify({beforeGlobal,after:viewportRect(svg).width,svgWidth:svg.style.width,zoom:root.style.getPropertyValue('zoom'),viewport:viewport.clientWidth,rootWidth:viewportRect(root).width}));
          if(Math.abs(tools.querySelector('button').getBoundingClientRect().width-button.width)>1)throw new Error('body zoom scaled diagram controls');
          if(document.documentElement.scrollWidth>innerWidth+2)throw new Error('diagram overflow escaped its viewport');
          window.setZoomLevel(1);
          other.scrollIntoView({block:'center'});
          const tall=viewportRect(other);
          if(tall.height<innerHeight)throw new Error('test requires a diagram taller than the screen');
          const tallPoint={x:tall.left+tall.width/2,y:innerHeight/2,gesture:902};
          const tallFy=(tallPoint.y-tall.top)/tall.height;
          const tallButton=hosts[1].querySelector('button').getBoundingClientRect().width;
          for(let i=0;i<=40;i++) {
            if(window.applyPinchZoom(1,i/40,{...tallPoint,finished:i===40})!==null)throw new Error('full-screen diagram gesture escaped');
            const rect=viewportRect(other);
            if(Math.abs(rect.top+rect.height*tallFy-tallPoint.y)>3)throw new Error('full-screen diagram shook vertically');
          }
          if(Math.abs(viewportRect(other).height/tall.height-2)>0.03)throw new Error('tall diagram did not zoom');
          if(Math.abs(hosts[1].querySelector('button').getBoundingClientRect().width-tallButton)>1)throw new Error('tall diagram controls grew');
          const enlarged=viewportRect(other);
          if(window.resetZoomAt({x:enlarged.left+enlarged.width/2,y:innerHeight/2})!==null)throw new Error('diagram smart magnify escaped');
          if(Math.abs(viewportRect(other).height-tall.height)>2 || hosts[1].querySelectorAll('button')[1].textContent!=='100%')throw new Error('smart magnify did not restore diagram default');
          window.setZoomLevel(1.5);
          await new Promise(r=>setTimeout(r,50));
          other.scrollIntoView({block:'center'});
          const defaultAtReadingZoom=viewportRect(other).height;
          const at=viewportRect(other);
          window.applyPinchZoom(1.5,1,{x:at.left+at.width/2,y:innerHeight/2,gesture:903,finished:true});
          const zoomed=viewportRect(other);
          window.resetZoomAt({x:zoomed.left+zoomed.width/2,y:innerHeight/2});
          if(Math.abs(viewportRect(other).height-defaultAtReadingZoom)>2 || root.style.getPropertyValue('zoom')!=='1.5')throw new Error('diagram reset changed the document zoom');
          window.setZoomLevel(1);
        }
        return true;
        """),
        ("Reading zoom preserves text and chrome", """
        const zoomMetrics=[];
        for(const context of ['app','quicklook']) for(const side of ['left','right']) {
          window.setZoomLevel(1);
          await window.renderMarkdown(Array.from({length:80},(_,i)=>'## Section '+i+'\\n\\n'+('Reading anchor words for wrapping and continuity. '.repeat(8))).join('\\n\\n'),{context,fontSize:16});
          window.setContentsSide(side);
          const root=document.getElementById('markdown-preview'), toc=document.getElementById('toc-container');
          const para=root.querySelectorAll('p')[35];para.scrollIntoView({block:'center'});
          await new Promise(r=>setTimeout(r,50));
          const range=document.createRange();range.setStart(para.firstChild,20);range.setEnd(para.firstChild,21);
          const base=viewportRect(range), width=viewportRect(root).width;
          const tocWidth=toc.getBoundingClientRect().width, tocFont=getComputedStyle(toc).fontSize;
          if(Math.abs(tocWidth-240)>1 || toc.querySelector('.toc-nav').hidden)throw new Error('test requires a visible docked contents sidebar');
          for(const level of [1.5,2,0.5,3,1]) {
            const before=viewportRect(range);
            const start=performance.now();
            window.setZoomLevel(level,{x:before.left+before.width/2,y:before.top+before.height/2});
            const elapsed=performance.now()-start;
            await new Promise(r=>setTimeout(r,50));
            const after=viewportRect(range);
            zoomMetrics.push({context,side,level,drift:Math.abs(after.top-before.top),layoutMs:elapsed});
            if(Math.abs(after.top-before.top)>3)throw new Error('reading anchor jumped: '+JSON.stringify({context,side,level,before:before.top,after:after.top,scrollY}));
            if(Math.abs(after.height/base.height-level)>0.15)throw new Error('body did not scale: '+level+' '+after.height/base.height);
            if(Math.abs(toc.getBoundingClientRect().width-tocWidth)>1 || getComputedStyle(toc).fontSize!==tocFont)throw new Error('contents zoomed');
            if(Math.abs(viewportRect(root).width-width)>2 || document.documentElement.scrollWidth>innerWidth+1)throw new Error('zoom overflow');
            if(scrollY<100)throw new Error('jumped to document start');
          }
          const initial=viewportRect(range);
          const fixedPoint={x:initial.left+initial.width/2,y:initial.top+initial.height/2,gesture:17};
          for(let i=1;i<=40;i++) {
            window.setZoomLevel(1+i/40,fixedPoint);
            if(Math.abs(viewportRect(range).top-initial.top)>3)throw new Error('continuous gesture lost its original text anchor');
          }
          window.setZoomLevel(1,{...fixedPoint,finished:true});
        }
        window.webkit.messageHandlers.logger.postMessage('ZOOM metrics '+JSON.stringify(zoomMetrics));
        window.setZoomLevel(1);document.documentElement.dataset.tocDocked='false';return true;
        """),
        ("Reading zoom source and export isolation", """
        window.setZoomLevel(1);
        window.renderSource(Array.from({length:300},(_,i)=>'source line '+i+' with readable content').join('\\n'),'light');
        const root=document.getElementById('markdown-preview');
        window.scrollTo(0,document.documentElement.scrollHeight/2);
        const target=document.elementFromPoint(300,300);
        const range=document.caretRangeFromPoint(300,300);range.setEnd(range.startContainer,Math.min(range.startOffset+1,range.startContainer.length));
        const before=viewportRect(range);
        window.setZoomLevel(1.5,{x:before.left,y:before.top+before.height/2});
        if(Math.abs(viewportRect(range).top-before.top)>3)throw new Error('source anchor jumped');
        await window.renderMarkdown('# Export\\n\\nText',{context:'app'});
        window.setZoomLevel(2);
        const html=new DOMParser().parseFromString(window.exportHTML(),'text/html');
        const exportedBody=html.querySelector('.markdown-body');
        if(!exportedBody || exportedBody.style.getPropertyValue('zoom'))throw new Error('reading zoom leaked into export');
        window.setZoomLevel(1);return true;
        """),
        ("Reading zoom rich content at narrow widths", """
        for(const context of ['app','quicklook']) for(const uiLanguage of ['en','ar']) {
          await window.renderMarkdown('# Rich content\\n\\nReadable paragraph with wrapping.\\n\\n![Diagram](diagram.svg)\\n\\n$E=mc^2$\\n\\n|One|Two|\\n|---|---|\\n|'+('longvalue'.repeat(40))+'|Data|\\n\\n```js\\n'+('longcode'.repeat(40))+'\\n```',{context,uiLanguage,imageData:{'diagram.svg':sizingSVGData}});
          await window.waitForExportReady();
          const root=document.getElementById('markdown-preview');
          const image=root.querySelector('img'), table=root.querySelector('table');
          for(const scale of [0.5,1.5,3,1]) {
            window.setZoomLevel(scale);
            if(document.documentElement.scrollWidth>innerWidth+2)throw new Error('rich zoom overflows page: '+JSON.stringify({context,uiLanguage,scale,width:document.documentElement.scrollWidth}));
            if(viewportRect(image).width>viewportRect(root).width+1)throw new Error('diagram exceeds reading column');
            if(table.scrollWidth<=table.clientWidth)throw new Error('wide table lost local scrolling');
          }
          root.querySelector('.svg-image-diagram .diagram-tools [data-diagram-zoom=in]').click();
          const localWidth=viewportRect(image).width;
          window.setZoomLevel(1.5);window.setZoomLevel(1);
          if(Math.abs(viewportRect(image).width-localWidth)>1)throw new Error('reading zoom erased diagram scale');
        }
        return true;
        """),
        ("SVG and Mermaid shared zoom controls", """
        for(const context of ['app','quicklook']) {
          await window.renderMarkdown('Body text\\n\\n![Diagram](diagram.svg)\\n\\n[![Linked](diagram.svg)](https://example.com)\\n\\n```mermaid\\ngraph TD; A-->B\\n```',{context,fontSize:16,imageData:{'diagram.svg':sizingSVGData}});
          await window.waitForExportReady();
          const root=document.getElementById('markdown-preview');
          const images=root.querySelectorAll('img'), mermaid=root.querySelector('.mermaid svg');
          const hosts=root.querySelectorAll('.svg-image-diagram');
          if(hosts.length!==2)throw new Error('SVG controls missing');
          const base=images[0].getBoundingClientRect().width, other=images[1].getBoundingClientRect().width, mermaidBase=mermaid.getBoundingClientRect().width;
          const buttons=hosts[0].querySelectorAll('button');
          buttons[2].click();
          if(Math.abs(images[0].getBoundingClientRect().width/base-1.25)>0.01)throw new Error('SVG zoom factor mismatch');
          if(images[1].getBoundingClientRect().width!==other || mermaid.getBoundingClientRect().width!==mermaidBase)throw new Error('SVG zoom changed another diagram');
          buttons[1].click();
          if(Math.abs(images[0].getBoundingClientRect().width-base)>1)throw new Error('SVG reset changed automatic size');
          const rect=images[0].getBoundingClientRect(), viewport=hosts[0].querySelector('.svg-image-viewport').getBoundingClientRect();
          if(Math.abs(rect.left-viewport.left-(viewport.right-rect.right))>1)throw new Error('SVG reset lost centering');
          buttons[0].click();if(images[0].getBoundingClientRect().width>=base)throw new Error('SVG zoom out failed');
          buttons[1].click();buttons[2].focus();
          await new Promise(resolve=>requestAnimationFrame(()=>resolve()));
          if(document.activeElement!==buttons[2] || getComputedStyle(hosts[0].querySelector('.diagram-tools')).opacity!=='1') {
            throw new Error('SVG keyboard controls hidden: '+JSON.stringify({focused:document.hasFocus(),active:document.activeElement?.tagName,disabled:buttons[2].disabled,focusWithin:hosts[0].querySelector('.diagram-tools').matches(':focus-within')}));
          }
          root.querySelector('.mermaid .diagram-tools [data-diagram-zoom=in]').click();
          if(mermaid.getBoundingClientRect().width<=mermaidBase || images[0].getBoundingClientRect().width!==base)throw new Error('Mermaid zoom not independent');
          if(images[1].closest('a')?.href!=='https://example.com/')throw new Error('SVG link lost');
          root.style.width='360px';root.style.maxWidth='none';
          buttons[2].click();buttons[2].click();
          await new Promise(r=>setTimeout(r,50));
          const scroll=hosts[0].querySelector('.svg-image-viewport');
          if(scroll.scrollWidth<=scroll.clientWidth)throw new Error('enlarged SVG cannot scroll locally');
          const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(exported.querySelector('.diagram-tools'))throw new Error('diagram controls leaked into export');
          root.style.width='';root.style.maxWidth='';
        }
        await window.renderMarkdown('# Replacement');
        if(document.querySelector('.svg-image-diagram,.diagram-tools'))throw new Error('stale diagram controls');
        return true;
        """),
        ("Referenced SVG intrinsic sizing at fullscreen widths", """
        const source=new DOMParser().parseFromString(atob(sizingSVGData.split(',')[1]),'image/svg+xml');
        const box=source.documentElement.getAttribute('viewBox').split(/[ ,]+/).map(Number);
        for(const context of ['app','quicklook','finder']) {
          await window.renderMarkdown('Body text\\n\\n![Diagram](diagram.svg)\\n\\n<img src="diagram.svg" width="96">',{context,fontSize:16,imageData:{'diagram.svg':sizingSVGData}});
          await window.waitForExportReady();
          const root=document.getElementById('markdown-preview'), img=root.querySelector('img');
          if(Math.abs(img.naturalWidth-box[2])>1 || Math.abs(img.naturalHeight-box[3])>1)throw new Error('SVG internal viewport differs from drawing: '+img.naturalWidth+'x'+img.naturalHeight);
          for(const width of [360,1800]) {
            root.style.width=width+'px';root.style.maxWidth='none';
            const rect=img.getBoundingClientRect();
            const parent=img.parentElement.getBoundingClientRect();
            if(Math.abs((rect.left-parent.left)-(parent.right-rect.right))>1)throw new Error('standalone SVG not centered in reading column');
            if(rect.width>Math.min(width,box[2])+1)throw new Error('SVG expanded beyond drawing width: '+rect.width);
            if(width===1800 && rect.width<box[2]*0.8)throw new Error('SVG shrank below readable native size: '+rect.width);
            if(Math.abs(rect.width/rect.height-box[2]/box[3])>0.01)throw new Error('SVG aspect ratio changed');
            if(16*rect.width/box[2]>parseFloat(getComputedStyle(root).fontSize)+0.1)throw new Error('SVG labels larger than body');
          }
          root.style.fontSize='12px';
          if(img.getBoundingClientRect().width>box[2]*0.75+1)throw new Error('SVG font-size change ignored');
          root.style.fontSize='24px';
          if(img.getBoundingClientRect().width>box[2]+1)throw new Error('SVG enlarged with larger body text');
          root.style.fontSize='16px';
          if(root.querySelectorAll('img')[1].getBoundingClientRect().width>97)throw new Error('explicit icon size enlarged');
          const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(!exported.querySelector('img').style.maxWidth.includes('px'))throw new Error('SVG export cap missing');
          if(!exported.querySelector('img').classList.contains('svg-standalone'))throw new Error('SVG export alignment missing');
          root.style.width='';root.style.maxWidth='';
        }
        await window.renderMarkdown('# Reset'); return true;
        """),
        ("Mermaid body-size cap and independent zoom at narrow/fullscreen widths", """
        const sources=['graph TD; A[Small diagram]-->B[Second node]', 'sequenceDiagram\\nAlice->>Bob: Hello\\nBob-->>Alice: Hi', 'gantt\\ntitle Schedule\\ndateFormat YYYY-MM-DD\\nsection Work\\nTask :2026-01-01, 3d', 'classDiagram\\nAnimal <|-- Duck\\nAnimal : +int age'];
        for(const source of sources) {
          await window.renderMarkdown('Body text\\n\\n```mermaid\\n'+source+'\\n```\\n\\n```mermaid\\ngraph TD; X-->Y\\n```',{fontSize:16,context:'app'});
          const root=document.getElementById('markdown-preview');
          for(const width of [360,1600]) {
            root.style.width=width+'px';root.style.maxWidth='none';
            window.dispatchEvent(new Event('resize'));
            await new Promise(resolve=>setTimeout(resolve,50));
            for(const host of root.querySelectorAll('.mermaid')) {
              const svg=host.querySelector('svg');if(!svg)throw new Error('diagram failed');
              const scale=svg.getBoundingClientRect().width/svg.viewBox.baseVal.width;
              const body=parseFloat(getComputedStyle(root).fontSize);
              for(const label of svg.querySelectorAll('text,tspan,foreignObject *')) {
                if(![...label.childNodes].some(n=>n.nodeType===3&&n.textContent.trim()))continue;
                if(parseFloat(getComputedStyle(label).fontSize)*scale>body+0.5)throw new Error('label exceeds body size');
              }
              if(svg.getBoundingClientRect().width>host.clientWidth+1)throw new Error('automatic diagram overflows');
            }
          }
          const diagrams=root.querySelectorAll('.mermaid');
          const first=diagrams[0].querySelector('svg'), second=diagrams[1].querySelector('svg');
          const before=first.getBoundingClientRect().width, other=second.getBoundingClientRect().width;
          const buttons=diagrams[0].querySelectorAll('button');
          buttons[2].click();
          if(first.getBoundingClientRect().width<=before||second.getBoundingClientRect().width!==other)throw new Error('zoom not isolated');
          buttons[1].click();if(Math.abs(first.getBoundingClientRect().width-before)>1)throw new Error('reset mismatch');
          buttons[0].focus();if(getComputedStyle(diagrams[0].querySelector('.mermaid-tools')).opacity!=='1')throw new Error('keyboard controls hidden');
          const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(exported.querySelector('.mermaid-tools'))throw new Error('controls leaked into export');
          root.style.width='';root.style.maxWidth='';
        }
        await window.renderMarkdown('# Reset');return true;
        """),
        ("lightweight definition abbreviation and insertion syntax", """
        const source='Term\\n: Definition **bold**\\n\\nHTML and ++inserted++ and `++literal++`\\n\\n*[HTML]: HyperText Markup Language';
        for(const context of ['app','quicklook','finder']) for(const theme of ['light','dark']) {
          await window.renderMarkdown(source,{context,theme});
          const root=document.getElementById('markdown-preview');
          if(root.querySelector('dt')?.textContent!=='Term'||root.querySelector('dd strong')?.textContent!=='bold')throw new Error('definition list lost');
          if(root.querySelector('abbr')?.title!=='HyperText Markup Language'||root.querySelector('ins')?.textContent!=='inserted'||root.querySelector('code')?.textContent!=='++literal++')throw new Error('inline extension mismatch');
          for(const el of root.querySelectorAll('dt,dd,abbr,ins')) {
            const box=el.getBoundingClientRect();if(box.width<=0||box.height<=0)throw new Error('invisible extension');
          }
          await window.waitForExportReady();
          const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(!exported.querySelector('dl')||!exported.querySelector('abbr[title]')||!exported.querySelector('ins'))throw new Error('export lost extensions');
        }
        await window.renderMarkdown('HTML',{context:'app',theme:'light'});
        if(document.querySelector('#markdown-preview abbr'))throw new Error('abbreviation leaked across documents');
        await window.renderMarkdown(source,{context:'app'});window.showSearch();
        const input=document.querySelector('.search-input');input.value='inserted';input.dispatchEvent(new Event('input',{bubbles:true}));
        if(!document.querySelector('.search-match-counter').textContent.includes('/1'))throw new Error('inserted text not searchable');
        window.hideSearch();await window.renderMarkdown('# Reset');return true;
        """),
        ("mixed-language contents direction and targets", """
        for(const uiLanguage of ['en','ar']) for(const contentsSide of ['left','right']) {
          await window.renderMarkdown('# مقدمة\\n\\n## שלום עולם\\n\\n## English title\\n\\n## التفاصيل\\n\\n## التفاصيل',{context:'app',uiLanguage,contentsSide});
          const links=[...document.querySelectorAll('.toc-link')];
          if(links.length!==5)throw new Error('missing headings');
          if(new Set(links.map(a=>a.hash)).size!==5)throw new Error('duplicate anchors');
          for(let i=0;i<links.length;i++) {
            const link=links[i], rtl=i!==2;
            const target=document.getElementById(decodeURIComponent(link.hash.slice(1)));
            if(!target)throw new Error('missing target');
            const style=getComputedStyle(link);
            if(style.direction!==(rtl?'rtl':'ltr'))throw new Error('wrong heading direction');
            if(!(rtl?parseFloat(style.paddingRight)>parseFloat(style.paddingLeft):parseFloat(style.paddingLeft)>parseFloat(style.paddingRight)))throw new Error('wrong indentation');
            link.classList.add('active');
            const marker=getComputedStyle(link,'::before');
            if((rtl?marker.right:marker.left)!=='0px')throw new Error('wrong active edge');
            link.click();
            if(link.getAttribute('aria-current')!=='location')throw new Error('navigation did not activate target');
          }
          if(document.documentElement.dataset.tocSide!==contentsSide)throw new Error('physical side changed');
        }
        await window.renderMarkdown('# Reset',{uiLanguage:'en',contentsSide:'right'}); return true;
        """),
        ("Quick Look probe requires completed visible current fixture", """
        const heading='FluxMarkdown Quick Look Test', bold='Rendered Markdown';
        const fixture='# '+heading+'\\n\\n**'+bold+'** confirms the extension was selected.';
        const verify=()=>window.verifyQuickLookProbe(heading,bold);
        await window.renderMarkdown(fixture,{context:'quicklook'});
        if(!verify())throw new Error('valid fixture rejected');
        window.invalidateRender();
        if(verify())throw new Error('stale generation accepted');
        await window.renderMarkdown(fixture,{context:'quicklook'});
        window.renderSource(fixture,'light');
        if(verify())throw new Error('source accepted');
        await window.renderMarkdown(fixture,{context:'quicklook'});
        const root=document.getElementById('markdown-preview');
        root.style.display='none';
        if(verify())throw new Error('hidden fixture accepted');
        root.style.display='';
        root.id='temporarily-missing-preview';
        await window.renderMarkdown(fixture,{context:'quicklook'});
        if(verify())throw new Error('missing root accepted');
        root.id='markdown-preview';
        if(verify())throw new Error('old content accepted after failed render');
        await window.renderMarkdown('# Wrong',{context:'quicklook'});
        if(verify())throw new Error('wrong fixture accepted');
        await window.renderMarkdown(fixture,{context:'quicklook'});
        const random=crypto.getRandomValues;
        crypto.getRandomValues=()=>{throw new Error('injected probe failure')};
        try{await window.renderMarkdown(fixture,{context:'quicklook'});}finally{crypto.getRandomValues=random;}
        if(verify() || !root.querySelector('.render-error'))throw new Error('caught failure accepted');
        await window.renderMarkdown('# Restored',{context:'app'});
        return true;
        """),
        ("Quick Look follow timed updates", """
        const options={context:'quicklook',followFile:true,showCopyButtons:true};
        const wait=()=>new Promise(r=>setTimeout(r,80));
        let text='# Timed Follow\\n\\n'+Array.from({length:200},(_,i)=>'Paragraph '+i+': stable text.').join('\\n\\n')+'\\n\\n';
        await window.renderMarkdown(text,options);window.setQuickLookFollow(true);await wait();
        const check=label=>{
          if(window.quickLookFollowStatus().paused)throw new Error('Unexpected pause: '+label);
          const last=document.getElementById('markdown-preview').lastElementChild.getBoundingClientRect();
          if(last.bottom>innerHeight+1 || last.top<0)throw new Error('Tail outside viewport: '+label);
        };
        for(let i=0;i<20;i++){text+='APPEND-'+i+'\\n\\n';await window.renderMarkdown(text,options);await wait();check('append '+i);}
        await window.renderMarkdown('# Short\\n\\nFINAL-SHORT',options);await wait();check('shrink');
        await window.renderMarkdown(text+'FINAL-GROWN',options);await wait();check('grow');
        dispatchEvent(new WheelEvent('wheel',{deltaY:-100}));
        if(!window.quickLookFollowStatus().paused)throw new Error('User wheel did not pause');
        window.setQuickLookFollow(true);await wait();check('resume');
        window.setQuickLookFollow(false);return true;
        """),
        ("Progressive commit shows first pages quickly", """
        const options={context:'quicklook',followFile:true,showCopyButtons:true,showLineNumbers:false,documentGeneration:'progressive'};
        const root=document.getElementById('markdown-preview');
        let text='# Session\\n\\n';
        for(let i=0;text.length<2000000;i++)text+='## Turn '+i+'\\n\\n> prompt '+i+'\\n\\nReply '+'words '.repeat(80)+'\\n\\n```text\\n'+('log line '+i+'\\n').repeat(12)+'```\\n\\n| a | b |\\n|---|---|\\n| '+i+' | x |\\n\\n';
        const t0=performance.now();let previous=t0,longest=0,firstText=null;
        const beat=setInterval(()=>{const now=performance.now();longest=Math.max(longest,now-previous-16);previous=now;},16);
        const observer=new MutationObserver(()=>{if(firstText===null&&root.querySelector('[data-source-line]')){firstText=performance.now()-t0;observer.disconnect();}});
        observer.observe(root,{childList:true});
        await window.renderMarkdown(text,options);
        const total=performance.now()-t0;
        await new Promise(r=>setTimeout(r,100));clearInterval(beat);
        const result={firstText:Math.round(firstText),longest:Math.round(longest),total:Math.round(total),visibility:document.visibilityState};
        if(!root.textContent.includes('Turn 0')||root.querySelectorAll('h2').length<1000)throw new Error('incomplete');
        // The first pages must appear well before the whole window is done.
        if(firstText===null||result.firstText*2>result.total)throw new Error('first pages were not shown first: '+JSON.stringify(result));
        // Step 3 target (update-quicklook-large-documents): first text within 300 ms, no task over 200 ms.
        // Timing is checked on a real Mac only; shared CI runners are far slower and uneven.
        if(strictTiming&&(result.firstText>300||result.longest>200))throw new Error('progressive commit missed its target: '+JSON.stringify(result));
        return true;
        """),
        ("Large document line numbers stay visible", """
        const root=document.getElementById('markdown-preview');
        let text='';
        for(let i=0;text.length<450000;i++)text+='## Section '+i+'\\n\\n'+'Body text. '.repeat(40)+'\\n\\n';
        for(const showLineNumbers of [true,false]) {
          await window.renderMarkdown(text,{context:'quicklook',showLineNumbers,progressive:false});
          const first=root.querySelector(':scope > [data-source-line]');
          const skipped=getComputedStyle(first).contentVisibility==='auto';
          if(showLineNumbers && skipped)throw new Error('Skipped layout clips the line-number gutter');
          if(showLineNumbers && getComputedStyle(first,'::before').content!=='"1"')throw new Error('First line number missing');
          if(showLineNumbers && getComputedStyle(first,'::before').whiteSpace!=='nowrap')throw new Error('Long line numbers wrap');
          if(!showLineNumbers && !skipped)throw new Error('Large document lost skipped layout');
        }
        return true;
        """),
        ("Quick Look tail window keeps file lines and shows the end", """
        const options={context:'quicklook',followFile:true,showCopyButtons:true,sourceLineStart:86169};
        const root=document.getElementById('markdown-preview');
        let text='---\\nnot front matter\\n---\\n\\n';
        for(let i=0;i<400;i++)text+='## Turn '+i+'\\n\\nline '+i+'\\n\\n```text\\nlog '+i+'\\n```\\n\\n';
        text+='LAST-LINE\\n';
        await window.renderMarkdown(text,options);window.setQuickLookFollow(true);await window.renderMarkdown(text,options);
        await new Promise(r=>setTimeout(r,80));
        if(root.firstElementChild.tagName!=='HR'||root.firstElementChild.getAttribute('data-source-line')!=='86170')throw new Error('window start: '+root.firstElementChild.outerHTML.slice(0,120));
        const last=root.lastElementChild;
        if(!last.textContent.includes('LAST-LINE'))throw new Error('last block missing');
        const box=last.getBoundingClientRect();
        if(box.bottom>innerHeight+1||box.top<0)throw new Error('last line not visible');
        window.setQuickLookFollow(false);return true;
        """),
        ("Quick Look follow appends to a two-mebibyte document", """
        const options={context:'quicklook',followFile:true,showCopyButtons:true};
        const root=document.getElementById('markdown-preview');
        const block=i=>'## Turn '+i+'\\n\\nOutput line '+i+' '+'x'.repeat(600)+'\\n\\n```text\\n'+'log '.repeat(150)+'\\n```\\n\\n';
        let text='# Session\\n\\n';
        for(let i=0;text.length<2000000;i++)text+=block(i);
        let started=performance.now();
        await window.renderMarkdown(text,options);
        const full=performance.now()-started;
        window.setQuickLookFollow(true);await window.renderMarkdown(text,options);
        const headings=root.querySelectorAll('h2'), first=root.firstElementChild, middle=headings[Math.floor(headings.length/2)];
        let slowest=0;
        for(let i=0;i<10;i++){
          const added='Appended paragraph '+i+'\\n\\n';
          started=performance.now();
          const result=await window.renderMarkdown(added,{...options,followAppendBase:text.length});
          slowest=Math.max(slowest,performance.now()-started);
          if(result)throw new Error('append '+i+' asked for a full render');
          text+=added;
        }
        if(root.firstElementChild!==first||!root.contains(middle))throw new Error('earlier blocks were replaced: first '+(root.firstElementChild===first)+', middle '+root.contains(middle));
        if(!root.textContent.includes('Appended paragraph 9'))throw new Error('missing appended text');
        if(slowest>full/4)throw new Error('append took '+Math.round(slowest)+' ms; full render '+Math.round(full)+' ms');
        if((await window.renderMarkdown('x',{...options,followAppendBase:1}))?.needsFullRender!==true)throw new Error('mismatched base accepted');
        window.clearDiffMarks&&window.clearDiffMarks();
        const clean=html=>html.replace(/ class=""/g,'').replace(/ style="(animation-delay: \\d+ms;)?"/g,'');
        const incremental=clean(root.innerHTML);
        window.setQuickLookFollow(false);
        await window.renderMarkdown(text,{...options,followFile:false});
        if(clean(root.innerHTML)!==incremental)throw new Error('incremental result differs from a full render');
        return true;
        """),
        ("Quick Look follow suffix and scroll", """
        const options={context:'quicklook',followFile:true,showCopyButtons:true};
        const text='# Follow\\n\\n'+Array.from({length:80},(_,i)=>'paragraph '+i).join('\\n\\n')+'\\n\\n';
        await window.renderMarkdown(text,options);
        const root=document.getElementById('markdown-preview');
        window.setQuickLookFollow(true);
        await window.renderMarkdown(text,options);
        const first=root.firstElementChild;
        await window.renderMarkdown(text+'new ending',options);
        if(root.firstElementChild!==first)throw new Error('unchanged heading replaced');
        if(document.documentElement.scrollHeight-innerHeight-scrollY>5)throw new Error('not following end');
        const last=root.lastElementChild.getBoundingClientRect();
        if(last.bottom>innerHeight+1 || last.top<0)throw new Error('last line obscured');
        dispatchEvent(new WheelEvent('wheel',{deltaY:-100}));
        if(!window.quickLookFollowStatus().paused)throw new Error('navigation did not pause');
        await window.renderMarkdown(text+'new ending extended',options);
        if(!root.textContent.includes('new ending extended'))throw new Error('missing last append');
        window.setQuickLookFollow(false);
        await window.renderMarkdown('restored',{context:'app'});
        return true;
        """),
        ("block copy delayed visibility and focus", """
        await window.renderMarkdown('```\\nhello\\n```',{context:'app',showCopyButtons:true});
        const nativeFocusDeadline=performance.now()+4000;
        while(!document.hasFocus() && performance.now()<nativeFocusDeadline)await new Promise(r=>setTimeout(r,50));
        if(!document.hasFocus())throw new Error('Environment: native test window did not become active');
        const tools=document.querySelector('.block-copy-tools'),button=tools.querySelector('button');
        if(getComputedStyle(button).pointerEvents!=='auto')throw new Error('Hidden copy button rejects the first pointer click');
        const opacity=()=>Number(getComputedStyle(tools).opacity);
        const hoverless=matchMedia('(hover: none)').matches;
        const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
        const waitForOpacity=async expected=>{
          const deadline=performance.now()+4000;
          while(Math.abs(opacity()-expected)>0.001 && performance.now()<deadline)await new Promise(r=>setTimeout(r,50));
        };
        await waitForOpacity(0);
        if(!hoverless && opacity()!==0) throw new Error('Idle copy button is visible '+JSON.stringify({opacity:opacity(),active:document.activeElement?.outerHTML,hover:tools.parentElement.matches(':hover'),focus:tools.matches(':focus-within'),state:tools.dataset.copyState,hoverless,reduced}));
        button.focus();
        await new Promise(r=>setTimeout(r,30));
        if(opacity()!==1) throw new Error('Keyboard focus did not reveal copy '+JSON.stringify({opacity:opacity(),active:document.activeElement?.outerHTML,focus:tools.matches(':focus-within'),hoverless}));
        button.blur();
        if(!hoverless && !reduced) {
          await new Promise(r=>setTimeout(r,300));
          if(opacity()!==1)throw new Error('Copy hid before exit delay');
          button.focus();
          await new Promise(r=>setTimeout(r,700));
          if(opacity()!==1)throw new Error('Reentry did not cancel hiding');
          button.blur();
          await waitForOpacity(0);
          if(opacity()!==0)throw new Error('Copy did not fade out');
        }
        tools.dataset.copyState='error';
        if(opacity()!==1)throw new Error('Failure recovery is hidden');
        delete tools.dataset.copyState;
        await window.renderMarkdown('# Reset',{showCopyButtons:false}); return true;
        """),
        ("block copy contexts, accessibility, export and synthetic-event rejection", """
        window.setFeedbackGeneration('33333333-3333-3333-3333-333333333333');
        const sample='```sh\\n\\techo "中文 & 😀"\\n\\n```\\n\\n> Quote\\n>\\n> > Nested\\n\\n> [!NOTE]\\n> Body';
        let writes=0;
        const original=window.webkit.messageHandlers.blockCopy;
        window.webkit.messageHandlers.blockCopy={postMessage:()=>{writes++}};
        for (const context of ['app','quicklook','finder']) {
          await window.renderMarkdown(sample,{context,showCopyButtons:true,showLineNumbers:true,uiLanguage:'en'});
          const buttons=[...document.querySelectorAll('.block-copy-tools > button')];
          if(context==='finder') {if(buttons.length) return false;continue;}
          if(buttons.length!==4 || buttons.some(b=>!b.getAttribute('aria-label')||b.type!=='button')) return false;
          buttons[0].click();
          if(writes!==0) return false;
          const html=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(html.querySelector('.block-copy-tools,.block-copy-host') || !html.querySelector('code').textContent.includes('中文')) return false;
          const pre=document.querySelector('pre').getBoundingClientRect();
          const toolbar=buttons[0].parentElement.getBoundingClientRect();
          if(toolbar.bottom>pre.top+1) throw new Error('Copy toolbar overlaps code');
        }
        window.webkit.messageHandlers.blockCopy=original;
        await window.renderMarkdown(sample,{context:'app',showCopyButtons:false});
        return !document.querySelector('.block-copy-tools,.block-copy-host');
        """),
        ("block copy narrow RTL geometry", """
        for(const uiLanguage of ['en','ar']) for(const theme of ['light','dark']) {
          await window.renderMarkdown('```\\n'+'LongCode'.repeat(400)+'\\n```\\n\\n> Quote',{context:'app',showCopyButtons:true,uiLanguage,theme});
          for(const button of document.querySelectorAll('.block-copy-tools > button')) {
            const rect=button.getBoundingClientRect();
            if(rect.width<20 || rect.left<0 || rect.right>window.innerWidth+1) return false;
            if(!button.getAttribute('aria-label'))return false;
          }
          const pre=document.querySelector('pre');
          if(pre.scrollWidth<=pre.clientWidth || document.documentElement.scrollWidth>window.innerWidth+1)return false;
        }
        await window.renderMarkdown('# Reset',{context:'app',uiLanguage:'en',theme:'light'});return true;
        """),
        ("block copy large document timing", """
        const text=Array(300).fill('```sh\\n  echo hello\\n```\\n\\n> A quoted paragraph.\\n').join('\\n');
        const samples={off:[],on:[]};
        for(let i=0;i<3;i++) for(const enabled of [false,true]) {
          const start=performance.now();
          await window.renderMarkdown(text,{context:'app',showCopyButtons:enabled,showLineNumbers:false});
          samples[enabled?'on':'off'].push(performance.now()-start);
          if(document.querySelectorAll('.block-copy-tools').length!==(enabled?600:0))return false;
        }
        window.webkit.messageHandlers.logger.postMessage('COPY performance ms '+JSON.stringify(samples));
        await window.renderMarkdown('# Reset',{showCopyButtons:false}); return true;
        """),
        ("TSV safe bounded table and source", """
        const row=Array(100).fill('<img src=x>').join('\\t');
        const start=performance.now();
        await window.renderMarkdown(Array(201).fill(row).join('\\n'),{format:'tsv',context:'app',theme:'dark',uiLanguage:'en'});
        const elapsed=performance.now()-start;
        window.webkit.messageHandlers.logger.postMessage('TSV 20,000 cells render ms: '+elapsed);
        if(elapsed>1000 || document.querySelectorAll('td').length!==20000 || document.querySelector('#markdown-preview img')) return false;
        if(!window.exportHTML().includes('tsv-truncated')) return false;
        const snapshot=window.captureReadingState();snapshot.zoom=1.5;
        await window.renderMarkdown('a\\tb\\n1\\t2',{format:'tsv',context:'app',documentId:'tsv-reopen',readingState:snapshot});
        if(document.getElementById('markdown-preview').style.getPropertyValue('zoom')!=='1.5')return false;
        window.setZoomLevel(1);
        window.renderSource('a\\tb\\npartial','dark',undefined,{format:'tsv',isTruncated:true});
        if(!document.querySelector('.tsv-truncated'))return false;
        await window.renderMarkdown('# Restored',{uiLanguage:'en'});
        return document.querySelector('h1').textContent==='Restored'&&!document.querySelector('.tsv-truncated');
        """),
        ("contextual feedback bridge", """
        window.setFeedbackGeneration('11111111-1111-1111-1111-111111111111');
        await window.renderMarkdown('```mermaid'+String.fromCharCode(10)+'SAMPLE-DO-NOT-INCLUDE ! invalid'+String.fromCharCode(10)+'```');
        await new Promise(resolve=>setTimeout(resolve,20));
        const button=document.querySelector('.error-feedback-trigger');
        if(!button || document.querySelector('.error-feedback-panel'))return false;
        button.click();
        const exported=window.exportHTML();
        window.setFeedbackGeneration('22222222-2222-2222-2222-222222222222');
        button.click();
        return !exported.includes('data-feedback-action=');
        """),
        ("compact mathematical feedback entry", """
        window.setFeedbackGeneration('33333333-3333-3333-3333-333333333333');
        await window.renderMarkdown('$$'+String.fromCharCode(10)+String.fromCharCode(92)+'unknownMarkdownPreviewCommand{x}'+String.fromCharCode(10)+'$$',{uiLanguage:'zh-Hans'});
        await new Promise(resolve=>setTimeout(resolve,20));
        const region=document.querySelector('.error-feedback-region');
        const trigger=region?.querySelector('.error-feedback-trigger');
        if(!region || !trigger || trigger.textContent!=='! 反馈' || region.querySelectorAll('button').length!==1 || document.querySelector('.error-feedback-panel'))return false;
        const box=region.getBoundingClientRect(), badge=trigger.getBoundingClientRect();
        if(Math.abs(box.right-badge.right)>12 || badge.top<box.top || badge.top>box.top+12)return false;
        if(trigger.getAttribute('aria-haspopup')!=='dialog')return false;
        const exported=window.exportHTML();
        return !new DOMParser().parseFromString(exported,'text/html').querySelector('.error-feedback-region, [data-feedback-action]');
        """),
        ("compact feedback hover collision", """
        window.setFeedbackGeneration('55555555-5555-5555-5555-555555555555');
        const slash=String.fromCharCode(92), nl=String.fromCharCode(10);
        await window.renderMarkdown('$'+slash+'unknownCommand{x}$'+nl+nl+'$$'+nl+slash+'unknownCommand{x}'+nl+'$$'+nl+nl+'$x=1$',{uiLanguage:'zh-Hans',showCopyButtons:true});
        await new Promise(resolve=>setTimeout(resolve,30));
        const errors=[...document.querySelectorAll('.flux-math-source.math-error')];
        if(errors.length!==2)throw new Error('Expected inline and display syntax failures');
        for(const error of errors){
            const host=error.closest('.math-copy-host');
            const tools=host?.querySelector(':scope > .block-copy-tools');
            if(tools){
                tools.style.opacity='1'; tools.style.pointerEvents='auto';
                const feedback=error.closest('.error-feedback-region').querySelector('.error-feedback-trigger').getBoundingClientRect();
                const copy=tools.getBoundingClientRect();
                if(copy.width && copy.height && copy.left<feedback.right && copy.right>feedback.left && copy.top<feedback.bottom && copy.bottom>feedback.top)throw new Error('Copy toolbar overlaps feedback on hover');
            }
        }
        return !!document.querySelector('.flux-math-source:not(.math-error)')?.closest('.math-copy-host')?.querySelector('.block-copy-tools button');
        """),
        ("compact feedback focus and text bounds", """
        window.setFeedbackGeneration('44444444-4444-4444-4444-444444444444');
        const slash=String.fromCharCode(92);
        for (const fontSize of [24,32,14]) {
        await window.renderMarkdown('# 这不是 Issue'+String.fromCharCode(10).repeat(2)+'$'+slash+'unknownMarkdownPreviewCommand{x}$',{uiLanguage:'zh-Hans',fontSize,showLineNumbers:false});
        await new Promise(resolve=>setTimeout(resolve,30));
        const button=document.querySelector('.error-feedback-trigger');
        if(!button)throw new Error('No feedback button');
        button.focus();
        const range=document.createRange(); range.selectNodeContents(button);
        const text=range.getBoundingClientRect(), box=button.getBoundingClientRect(), style=getComputedStyle(button);
        window.webkit.messageHandlers.logger.postMessage('Feedback geometry '+JSON.stringify({text:text.toJSON(),box:box.toJSON(),outline:style.outline,appearance:style.appearance,font:style.font,width:style.width}));
        if(style.outlineStyle!=='none' || style.display!=='inline-flex')throw new Error('Native button chrome was not reset');
        if(text.left<box.left || text.right>box.right || text.top<box.top || text.bottom>box.bottom)throw new Error('Feedback text outside button');
        }
        return true;
        """),
        ("passive HTML", "await window.renderMarkdown('<img src=\"missing.png\" onerror=\"window.pwned=true\"><details><summary>ok</summary></details>'); return !document.querySelector('[onerror]') && !window.pwned && !!document.querySelector('details');"),
        ("new render wins", "const a=window.renderMarkdown('# OLD\\n\\n$x$'); const b=window.renderMarkdown('# NEW',{enableKatex:false}); await Promise.all([a,b]); return document.querySelector('h1').textContent==='NEW';"),
        ("display math copy controls preserve vertical spacing", """
        const formulas=[String.raw`\\[x=1\\]`, '$$\\nx=1\\n$$', '```math\\nx=1\\n```'];
        const root=document.getElementById('markdown-preview');
        for(const width of [300,800]) for(const uiLanguage of ['en','ar']) for(const context of ['app','quicklook']) {
          root.style.width=width+'px';
          for(const formula of formulas) {
            const source='Before formula.\\n\\n'+formula+'\\n\\nAfter formula.';
            let plain;
            for(const showCopyButtons of [false,true]) {
              await window.renderMarkdown(source,{context,showCopyButtons,uiLanguage});
              const math=document.querySelector('div.flux-math-source');
              const output=math.querySelector('mjx-container');
              const after=document.querySelector('#markdown-preview > p:last-child');
              const positions=[output.getBoundingClientRect().top,after.getBoundingClientRect().top];
              if(!showCopyButtons)plain=positions;
              else {
                const delta=positions.map((value,index)=>value-plain[index]);
                if(delta.some(value=>Math.abs(value)>1))throw new Error('Display copy adds '+delta+'px vertical gap in '+context);
                const button=math.parentElement.querySelector('.block-copy-tools > button');
                if(!button || button.disabled || button.tabIndex<0)throw new Error('Display copy control is inaccessible');
                const tools=button.parentElement;
                for(const state of ['pending','success']) {
                  tools.dataset.copyState=state;
                  if(Math.abs(output.getBoundingClientRect().top-plain[0])>1 || Math.abs(after.getBoundingClientRect().top-plain[1])>1)throw new Error('Copy status shifts display math');
                }
                tools.dataset.copyState='error';
                if(getComputedStyle(tools).position!=='static')throw new Error('Copy error recovery is outside document flow');

              }
              if(parseFloat(getComputedStyle(output).marginTop)<=0)throw new Error('Normal display margin was removed');
            }
          }
          const inline=String.raw`The space \\(A\\) is one-dimensional.`;
          let plainGap;
          for(const showCopyButtons of [false,true]) {
            await window.renderMarkdown(inline,{context,showCopyButtons,uiLanguage});
            const math=root.querySelector('.flux-math-source');
            const host=math.closest('.math-copy-inline') || math;
            const range=document.createRange();range.setStart(host.nextSibling,1);range.setEnd(host.nextSibling,2);
            const gap=range.getBoundingClientRect().left-math.getBoundingClientRect().right;
            if(!showCopyButtons)plainGap=gap;
            else if(Math.abs(gap-plainGap)>1)throw new Error('Inline spacing regressed');
          }
        }
        root.style.removeProperty('width');
        return true;
        """),
        ("inline math copy controls preserve text spacing", """
        const source=String.raw`The space \\(A\\) is one-dimensional.`;
        for(const context of ['app','quicklook']) {
          let plain;
          for(const showCopyButtons of [false,true]) {
            await window.renderMarkdown(source,{context,showCopyButtons});
            const math=document.querySelector('.flux-math-source');
            const host=math.closest('.math-copy-inline') || math;
            const text=host.nextSibling;
            const range=document.createRange();range.setStart(text,1);range.setEnd(text,2);
            const gap=range.getBoundingClientRect().left-math.getBoundingClientRect().right;
            if(!showCopyButtons)plain=gap;
            else {
              if(Math.abs(gap-plain)>1)throw new Error('Inline copy adds '+(gap-plain)+'px gap in '+context);
              const button=host.querySelector('button');button.focus();
              await new Promise(requestAnimationFrame);
              if(document.activeElement!==button || getComputedStyle(button.parentElement).opacity!=='1')throw new Error('Copy control is inaccessible');
              if(Math.abs(range.getBoundingClientRect().left-math.getBoundingClientRect().right-plain)>1)throw new Error('Focus shifts prose');
            }
          }
        }
        return true;
        """),
        ("math native keyboard copy and reference", """
        window.setFeedbackGeneration('math-keyboard');
        const source=String.raw`\\(\\frac{x}{2}\\)`;
        await window.renderMarkdown(source+'\\n\\n'+String.raw`\\(\\eqref{x}\\)`+'\\n\\n'+Array(60).fill('Spacer paragraph.').join('\\n\\n')+'\\n\\n'+String.raw`\\[x=1\\tag{A}\\label{x}\\]`,{context:'app',showCopyButtons:true});
        const nativeFocusDeadline=performance.now()+4000;
        while(!document.hasFocus() && performance.now()<nativeFocusDeadline)await new Promise(r=>setTimeout(r,50));
        if(!document.hasFocus())throw new Error('Environment: native test window did not become active');
        const button=document.querySelector('.math-copy-inline .block-copy-tools > button');
        button.focus();
        window.webkit.messageHandlers.nativeMathKey.postMessage('space');
        const deadline=performance.now()+5000;
        while(!document.querySelector('.math-copy-inline [data-copy-state="success"]') && performance.now()<deadline)await new Promise(r=>setTimeout(r,30));
        if(!document.querySelector('.math-copy-inline [data-copy-state="success"]'))throw new Error('Native key copy was not acknowledged');
        const link=document.querySelector('a.math-reference-link');
        const target=document.getElementById(decodeURIComponent(link.getAttribute('href').slice(1)));
        const before=target.getBoundingClientRect().top;
        link.focus();window.webkit.messageHandlers.nativeMathKey.postMessage('enter');
        const until=performance.now()+3000;
        while(target.getBoundingClientRect().top>window.innerHeight && performance.now()<until)await new Promise(r=>setTimeout(r,30));
        if(!(before>window.innerHeight && target.getBoundingClientRect().top<window.innerHeight))throw new Error('Reference did not scroll into view');
        await window.renderMarkdown('$'+Array(80).fill('x').join('+')+'$',{context:'app',showCopyButtons:false});
        const scrolling=document.querySelector('.math-inline-overflow');
        if(!scrolling || scrolling.tabIndex!==0)throw new Error('Wide inline formula lacks focusable scroll surface');
        scrolling.scrollLeft=0;scrolling.focus();
        const scrollKeyEvidence=[];
        scrolling.addEventListener('keydown',event=>{scrollKeyEvidence.push({key:event.key,trusted:event.isTrusted,focused:document.hasFocus(),prevented:event.defaultPrevented});},{once:true});
        window.webkit.messageHandlers.nativeMathKey.postMessage('right');
        const scrollDeadline=performance.now()+3000;
        while(scrolling.scrollLeft===0 && performance.now()<scrollDeadline)await new Promise(r=>setTimeout(r,30));
        if(!(scrolling.scrollLeft>0 && window.scrollX===0))throw new Error(JSON.stringify({scrollLeft:scrolling.scrollLeft,width:scrolling.clientWidth,scrollWidth:scrolling.scrollWidth,windowX:window.scrollX,active:document.activeElement?.className,tabIndex:scrolling.tabIndex,documentFocused:document.hasFocus(),keys:scrollKeyEvidence}));
        window.webkit.messageHandlers.nativeMathKey.postMessage('narrow');
        const narrowDeadline=performance.now()+3000;
        while(window.innerWidth>160 && performance.now()<narrowDeadline)await new Promise(r=>setTimeout(r,30));
        if(window.innerWidth>160)throw new Error('Native narrow zoom did not settle');
        for(const uiLanguage of ['en','de','ar']) for(const failedSource of [source, '$$'+String.fromCharCode(10)+String.raw`\\frac{x}{2}`+String.fromCharCode(10)+'$$']) {
          await window.renderMarkdown(failedSource,{context:'app',showCopyButtons:true,uiLanguage});
          document.querySelector('.math-copy-host .block-copy-tools > button').focus();
          window.webkit.messageHandlers.nativeMathKey.postMessage('failed-space');
          const failureDeadline=performance.now()+3000;
          while(!document.querySelector('.math-copy-source') && performance.now()<failureDeadline)await new Promise(r=>setTimeout(r,30));
          const recovery=document.querySelector('.math-copy-source');
          if(!recovery || recovery.value!==failedSource || !recovery.readOnly)throw new Error('Copy failure lost original formula');
          const live=document.querySelector('.math-copy-host [role="status"]');
          if(!live?.textContent.trim() || live.getAttribute('aria-live')!=='polite')throw new Error('Copy failure lacks a live status update');
          if(document.querySelector('.math-copy-host').textContent.split(live.textContent).length!==2)throw new Error('Copy failure instruction is duplicated');
          if(document.documentElement.scrollWidth>window.innerWidth+1)throw new Error('Copy failure causes whole-page horizontal overflow: '+uiLanguage);
          for(const control of document.querySelectorAll('.block-copy-error button,.math-copy-source')) {
            const rect=control.getBoundingClientRect();
            if(rect.width<=0 || rect.left< -1 || rect.right>innerWidth+1)throw new Error('Copy recovery control escapes the viewport');
          }
          const select=document.querySelector('.block-copy-error > button');
          select.focus();window.webkit.messageHandlers.nativeMathKey.postMessage('enter');
          const selectionDeadline=performance.now()+3000;
          while((document.activeElement!==recovery || recovery.selectionStart!==0 || recovery.selectionEnd!==failedSource.length) && performance.now()<selectionDeadline)await new Promise(r=>setTimeout(r,30));
          if(document.activeElement!==recovery || recovery.selectionStart!==0 || recovery.selectionEnd!==failedSource.length)throw new Error('Native select-source recovery failed');
          await window.waitForExportReady();
          const exported=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(exported.querySelector('.math-copy-source,.block-copy-error,.error-feedback-controls,.math-copy-host') || exported.querySelectorAll('mjx-container').length!==1)throw new Error('Copy failure polluted mathematical export');
        }
        window.webkit.messageHandlers.nativeMathKey.postMessage('restore-size');
        const restoreDeadline=performance.now()+3000;
        while(window.innerWidth<800 && performance.now()<restoreDeadline)await new Promise(r=>setTimeout(r,30));
        if(window.innerWidth<800)throw new Error('Native view size was not restored');
        await window.renderMarkdown('# Restored',{context:'app',uiLanguage:'en',showCopyButtons:false});
        return true;
        """),
        ("math baseline API compatibility and reference export", """
        const descriptor=Object.getOwnPropertyDescriptor(Object,'hasOwn');
        Reflect.deleteProperty(Object,'hasOwn');
        try {
          const source=String.raw`\\[x^2\\tag{A}\\label{constructor}\\]`+'\\n\\n'+String.raw`\\(\\eqref{constructor}\\)`;
          const rendering=window.renderMarkdown(source,{context:'quicklook'});
          await window.waitForExportReady();await rendering;
          const root=document.getElementById('markdown-preview');
          if(root.querySelectorAll('mjx-container').length!==2 || root.querySelector('.math-error'))return false;
          const html=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          const link=html.querySelector('a[href^="#"]');
          return typeof Object.hasOwn==='function' && !!link && !!html.getElementById(decodeURIComponent(link.getAttribute('href').slice(1))) && !html.querySelector('script');
        } finally {if(descriptor)Object.defineProperty(Object,'hasOwn',descriptor);}
        """),
        ("letter sequences and copyright typography", """
        for (const context of ['app','quicklook']) {
          await window.renderMarkdown('(a) first\\n\\n**(b)** second\\n\\n(c) third\\n\\n(c) 2026 (tm)',{context});
          const text=document.getElementById('markdown-preview').textContent;
          if(!text.includes('(c) third') || !text.includes('© 2026 ™')) return false;
          const html=new DOMParser().parseFromString(window.exportHTML(),'text/html');
          if(!html.body.textContent.includes('(c) third')) return false;
        }
        return true;
        """),
        ("editor-style line references", """
        const original=window.webkit.messageHandlers.linkClicked;
        const sent=[];
        window.webkit.messageHandlers.linkClicked={postMessage:href=>{sent.push(href)}};
        try {
          await window.renderMarkdown('[rel](notes.md:12)\\n\\n[abs](/tmp/文件.java:57)\\n\\n[col](src/Foo.java:57:4)\\n\\n[anchor](#section)\\n\\n<a href="javascript:1">unsafe</a>',{context:'app'});
          const links=[...document.querySelectorAll('#markdown-preview a')];
          const hrefs=links.map(a=>a.getAttribute('href'));
          if(links.length!==5) throw new Error('unexpected link count '+links.length+' '+JSON.stringify(hrefs));
          if(hrefs[0]!=='notes.md:12' || hrefs[1]!=='/tmp/%E6%96%87%E4%BB%B6.java:57' || hrefs[2]!=='src/Foo.java:57:4' || hrefs[3]!=='#section') throw new Error('hrefs '+JSON.stringify(hrefs));
          if(hrefs[4]!==null || document.querySelector('a[href^="javascript"]')) throw new Error('unsafe href survived '+JSON.stringify(hrefs));
          links[0].click(); links[2].click();
          if(sent.length!==2 || sent[0]!=='notes.md:12' || sent[1]!=='src/Foo.java:57:4') throw new Error('linkClicked payload '+JSON.stringify(sent));
        } finally { window.webkit.messageHandlers.linkClicked=original; }
        return true;
        """),
        ("math and emoji", "await window.renderMarkdown('$x$ :smile:'); await window.renderMarkdown(':smile:',{enableKatex:false}); return !document.getElementById('markdown-preview').textContent.includes(':smile:');"),
        ("native Typst offline", "const oldFetch=window.fetch; window.fetch=(url,...args)=>{if(/^https?:/.test(String(url))) throw new Error('Unexpected network font/package request'); return oldFetch(url,...args)}; await window.renderMarkdown('```typst\\nsum_(i=1)^n i\\n```',{context:'app'}); window.fetch=oldFetch; return !!document.querySelector('.typst-native svg use') && !document.querySelector('.typst-native style') && !document.querySelector('pre .typst-native');"),
        ("Mermaid", "await window.renderMarkdown('```mermaid\\ngraph TD; A-->B\\n```'); return !!document.querySelector('.mermaid svg') && !document.querySelector('.mermaid-error');"),
        ("Graphviz", "await window.renderMarkdown('```dot\\ndigraph { a -> b }\\n```'); const text=document.querySelector('.graphviz-diagram svg text');return text?.textContent==='a' && getComputedStyle(text).fill!=='none';"),
        ("Vega", "await window.renderMarkdown('```vega-lite\\n{\"data\":{\"values\":[{\"x\":1,\"y\":2}]},\"mark\":\"point\",\"encoding\":{\"x\":{\"field\":\"x\",\"type\":\"quantitative\"},\"y\":{\"field\":\"y\",\"type\":\"quantitative\"}}}\\n```'); return !!document.querySelector('.vega-diagram svg');"),
        ("slow export resource", "await window.renderMarkdown('# Slow'); const img=document.createElement('img'); document.getElementById('markdown-preview').append(img); Object.defineProperty(img,'complete',{value:false}); const start=performance.now(); setTimeout(()=>img.dispatchEvent(new Event('load')),3100); await window.waitForExportReady(5000); return performance.now()-start>=3000;"),
        ("issue 63 relative SVG", """
        for (const context of ['app', 'quicklook']) {
          for (const inline of [false, true]) {
            await window.renderMarkdown(svgMarkdown, {context, baseUrl:imageBase, imageData:inline ? svgImageData : undefined});
            try { await window.waitForExportReady(); } catch(e) { throw new Error(JSON.stringify({context,inline,images:[...document.querySelectorAll('#markdown-preview img')].map(i=>({src:i.src,width:i.naturalWidth}))})); }
            const images = [...document.querySelectorAll('#markdown-preview img')];
            if (images.length !== 3 || images.some(img => img.naturalWidth !== 96 || img.naturalHeight !== 96)) return false;
          }
        }
        return true;
        """),
        ("local image", "await window.renderMarkdown('![Image](pixel.png)',{baseUrl:imageBase}); await window.waitForExportReady(); return document.querySelector('#markdown-preview img').naturalWidth===1;"),
        ("export ready", "await window.renderMarkdown('# Export\\n\\n$\\\\frac{a}{b}$'); await window.waitForExportReady(5000); return !!document.querySelector('mjx-container svg') && !!document.querySelector('mjx-assistive-mml mfrac');"),
        ("search and refresh", "await window.renderMarkdown('# Search\\n\\nAlpha Alpha',{context:'app'});window.showSearch(); const input=document.querySelector('.search-input');input.value='Alpha';input.dispatchEvent(new Event('input',{bubbles:true}));if(!document.querySelector('.search-match-counter').textContent.includes('/2'))return false; await window.renderMarkdown('# Search\\n\\nAlpha Alpha Alpha',{context:'app'});const ok=input.value==='Alpha'&&document.querySelector('.search-match-counter').textContent.includes('/3');window.hideSearch();return ok;"),
        ("outline and positioned source", "await window.renderMarkdown('---\\ntitle: Test\\n---\\n# One\\n\\n## Two',{context:'app'});if(!document.querySelector('#toc-container a[href=\"#two\"]'))return false;if(!window.navigateDocumentPosition({line:6}))return false;window.renderSource('# One\\n\\n## Two','light');return document.getElementById('markdown-preview').classList.contains('source-mode') && window.navigateDocumentPosition({line:3});"),
        ("theme font zoom and RTL", "await window.renderMarkdown('# مرحبا بالعالم\\n\\nهذا نص عربي لاختبار اتجاه القراءة',{context:'app',theme:'dark'});window.setFontSize(18);window.setZoomLevel(1.25);const root=document.getElementById('markdown-preview');const ok=root.getAttribute('dir')==='rtl'&&document.documentElement.dataset.theme==='dark'&&root.style.fontSize==='18px';window.setZoomLevel(1);return ok;"),
        ("help controls", "window.showHelp();const open=!!document.querySelector('#help-overlay');window.hideHelp();return open;"),
        ("QuickLook Typst path", "await window.renderMarkdown('```typst\\na/b\\n```',{context:'quicklook'});return !!document.querySelector('.typst-transpiled .katex');"),
        ("export excludes application controls", "await window.renderMarkdown('# Export\\n\\n**Bold**',{context:'app',theme:'light'});const html=window.exportHTML();return html.includes('<strong>Bold</strong>')&&!html.includes('id=\"reading-controls\"')&&!html.includes('id=\"toc-container\"');"),
        ("wide reading layout", """
        for (const context of ['app','quicklook']) {
          const cols = Array.from({length:16},(_,i)=>'Column_'+i+'_'+ 'LongValue'.repeat(10)).join('|');
          await window.renderMarkdown('# Width\\n\\nParagraph fills available space.\\n\\n|'+cols+'|\\n|'+Array(16).fill('---').join('|')+'|\\n|'+cols+'|',{context});
          for (const docked of [false,true]) {
            document.documentElement.dataset.tocDocked=String(docked);
            const layout=document.getElementById('reading-layout');
            const root=document.getElementById('markdown-preview');
            const available=layout.clientWidth-(docked?264:0);
            const paragraph=root.querySelector('p'); const table=root.querySelector('table');
            const style=getComputedStyle(root); const insets=parseFloat(style.paddingLeft)+parseFloat(style.paddingRight)+parseFloat(style.borderLeftWidth)+parseFloat(style.borderRightWidth);
            if(Math.abs(root.getBoundingClientRect().width-available)>2 || insets>100 || paragraph.getBoundingClientRect().width<available-insets-2 || table.clientWidth<available-insets-2 || table.scrollWidth<=table.clientWidth) throw new Error(JSON.stringify({context,docked,available,root:root.getBoundingClientRect().width,paragraph:paragraph.getBoundingClientRect().width,table:table.clientWidth,scroll:table.scrollWidth,viewport:window.innerWidth,padding:getComputedStyle(root).padding,box:getComputedStyle(root).boxSizing,zoom:getComputedStyle(root).zoom}));
            if(document.documentElement.scrollWidth>window.innerWidth+1) return false;
          }
        }
        document.documentElement.dataset.tocDocked='false'; return true;
        """),
        ("narrow reading layout", """
        for (const context of ['app','quicklook']) {
          await window.renderMarkdown('# Narrow\\n\\nReading text.',{context});
          document.documentElement.dataset.tocDocked='false';
          const root=document.getElementById('markdown-preview');
          if(Math.abs(root.getBoundingClientRect().width-document.getElementById('reading-layout').clientWidth)>2 || document.documentElement.scrollWidth>window.innerWidth+1) return false;
        }
        return true;
        """),
        ("RTL wide geometry", """
        for (const context of ['app','quicklook']) for (const contentsSide of ['left','right']) {
          for (const uiLanguage of ['ar','en','ar']) {
            await window.renderMarkdown('# One\\n\\n## Two\\n\\nEnglish text and `code`.',{context,contentsSide,uiLanguage});
            await new Promise(resolve=>setTimeout(resolve,30));
            const toggle=document.querySelector('.toc-toggle');
            if (toggle.getAttribute('aria-expanded')!=='true') toggle.click();
            await new Promise(resolve=>setTimeout(resolve,30));
            const doc=document.getElementById('markdown-preview').getBoundingClientRect();
            const nav=document.querySelector('.toc-nav').getBoundingClientRect();
            const button=toggle.getBoundingClientRect();
            const left=contentsSide==='left';
            if (left ? nav.right>doc.left+2 : nav.left<doc.right-2) throw new Error(JSON.stringify({context,contentsSide,uiLanguage,doc:doc.toJSON(),nav:nav.toJSON()}));
            if (left ? button.left>window.innerWidth/2 : button.right<window.innerWidth/2) throw new Error('Contents entrance on wrong side');
            const controls=document.getElementById('reading-controls').getBoundingClientRect();
            const reserve=parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--reading-native-reserve'));
            if (document.documentElement.dataset.readingShared==='true' && controls.right>window.innerWidth-reserve+2) throw new Error('Native right edge not reserved');
            if (context==='app') {
              window.showSearch(); await new Promise(resolve=>setTimeout(resolve,20));
              const search=document.getElementById('search-container').getBoundingClientRect();
              if(Math.abs((search.left+search.right)/2-(doc.left+doc.right)/2)>2) throw new Error('Search not centered over document');
              window.hideSearch();
            }
          }
        }
        await window.renderMarkdown('# Reset',{uiLanguage:'en'}); return true;
        """),
        ("RTL narrow geometry", """
        for (const context of ['app','quicklook']) for (const contentsSide of ['left','right']) {
          await window.renderMarkdown('# One\\n\\n## Two',{context,contentsSide,uiLanguage:'ar'});
          await new Promise(resolve=>setTimeout(resolve,30));
          const toggle=document.querySelector('.toc-toggle');
          if(toggle.getAttribute('aria-expanded')!=='true') toggle.click();
          await new Promise(resolve=>setTimeout(resolve,30));
          const panel=document.getElementById('toc-container');
          const rect=panel.getBoundingClientRect();
          if(panel.dataset.layout!=='overlay' || (contentsSide==='left' ? Math.abs(rect.left-16)>2 : Math.abs(rect.right-(window.innerWidth-16))>2)) throw new Error(JSON.stringify({contentsSide,rect:rect.toJSON()}));
          document.querySelector('.toc-close').click();
        }
        await window.renderMarkdown('# Reset',{uiLanguage:'en'}); return true;
        """),
    ]
    let svgMarkdown = """
    <p align="center"><img src="plugin/assets/plugin.svg" alt="SQL Notebook" width="96" height="96"></p>

    ![SQL](plugin/assets/plugin.svg)

    ![](plugin/assets/plugin.svg)
    """
    var svgImageData: [String: String] = [:]
    var sizingSVGData = ""

    func run() {
        if let filter = ProcessInfo.processInfo.environment["FLUX_WEBKIT_CASE_FILTER"] {
            cases = cases.filter { $0.0.localizedCaseInsensitiveContains(filter) }
            guard !cases.isEmpty else { fputs("FAIL no matching integration cases\n", stderr); exit(1) }
        }
        let sizingSVG: Data
        if let fixture = ProcessInfo.processInfo.environment["FLUX_SVG_SIZING_FIXTURE"] {
            sizingSVG = try! BoundedFileReader.read(URL(fileURLWithPath: fixture), maxBytes: 8 * 1024 * 1024)
        } else {
            sizingSVG = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="100%" style="max-width:586.5px" viewBox="4 4 586.5 1088"><style>text {font-size:16px}</style><rect x="4" y="4" width="586.5" height="1088" fill="lightgray"/><text x="20" y="40">Diagram label</text></svg>"#.utf8)
        }
        let sizingDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
        try! sizingSVG.write(to: sizingDirectory.appendingPathComponent("diagram.svg"))
        let sizingImages = MarkdownImageDataCollector.collectImageData(
            from: sizingDirectory.appendingPathComponent("sizing.md"), content: "![Diagram](diagram.svg)", fileExtensions: ["svg"])
        guard let sizingData = sizingImages["diagram.svg"] else { fatalError("SVG sizing collector failed") }
        sizingSVGData = sizingData
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "logger")
        config.userContentController.add(self, name: "blockCopy")
        config.userContentController.add(self, name: "selectionCopy")
        config.userContentController.add(self, name: "diagramAction")
        config.userContentController.add(self, name: "nativeMathKey")
        config.userContentController.add(self, name: "errorFeedback")
        config.setURLSchemeHandler(RendererBundleSchemeHandler(rootDirectory: URL(fileURLWithPath: CommandLine.arguments[1])), forURLScheme: RendererBundleSchemeHandler.scheme)
        let imageDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
        let imageURL = imageDirectory.appendingPathComponent("pixel.png")
        try! Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!.write(to: imageURL)
        let images = LocalSchemeHandler()
        imageScheme = images
        images.baseDirectory = imageDirectory
        let svgURL = imageDirectory.appendingPathComponent("plugin/assets/plugin.svg")
        try! FileManager.default.createDirectory(at: svgURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! #"<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect width="96" height="96" fill="green"/></svg>"#.write(to: svgURL, atomically: true, encoding: .utf8)
        let markdownURL = imageDirectory.appendingPathComponent("issue63.md")
        svgImageData = MarkdownImageDataCollector.collectImageData(from: markdownURL, content: svgMarkdown)
        guard svgImageData["plugin/assets/plugin.svg"] != nil else { fatalError("SVG collector failed") }
        images.allowedFileURLs = MarkdownImageDataCollector.referencedLocalImageURLs(from: markdownURL, content: svgMarkdown).union([imageURL])
        for index in 1...33 {
            try! Data(contentsOf: imageURL).write(to: imageDirectory.appendingPathComponent("boundary-\(index).png"))
        }
        let boundaryMarkdown = (1...33).map { "![Image \($0)](boundary-\($0).png)" }.joined(separator: "\n")
        images.allowedFileURLs.formUnion(MarkdownImageDataCollector.referencedLocalImageURLs(from: markdownURL, content: boundaryMarkdown))
        let invalidImage = imageDirectory.appendingPathComponent("invalid.png")
        try! Data("invalid image bytes".utf8).write(to: invalidImage)
        images.allowedFileURLs.insert(invalidImage)
        config.setURLSchemeHandler(images, forURLScheme: "local-md")
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.load(URLRequest(url: RendererBundleSchemeHandler.rendererURL()))
        // The 2 MiB Follow and progressive-commit cases take about 70 s on a shared CI runner.
        DispatchQueue.main.asyncAfter(deadline: .now() + 240) { fputs("FAIL integration timeout\n", stderr); exit(1) }
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard RendererBridgePolicy.accepts(message) else { print("FAIL bridge origin"); exit(1) }
        if message.name == "diagramAction" {
            guard let request=DiagramExportRequest.decode(message.body,generation:"workflow-probe") else{print("FAIL diagram request validation");exit(1)}
            let directory=ProcessInfo.processInfo.environment["FLUX_WORKFLOW_ARTIFACT_DIR"] ?? CommandLine.arguments[2]
            try! FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
            let destination=URL(fileURLWithPath:directory).appendingPathComponent("diagram-"+request.id+"."+(request.action=="svg" ? "svg":"png"))
            diagramExport.perform(request,destination:destination,pasteboard:diagramPasteboard){result in
                switch result {
                case .failure(let error):print("FAIL diagram export service: \(error)");exit(1)
                case .success(let status):
                    if request.action=="copy" {
                        guard let data=self.diagramPasteboard.data(forType:.png),NSBitmapImageRep(data:data) != nil else{print("FAIL PNG clipboard readback");exit(1)}
                        try! data.write(to:destination)
                    }
                    self.webView.callAsyncJavaScript("window.diagramActionResult(id,generation,status);window.__workflowResults=(window.__workflowResults||[]).concat({id,status});",arguments:["id":request.id,"generation":request.generation,"status":status],in:nil,in:.page,completionHandler:nil)
                }
            }
            return
        }
        if message.name == "blockCopy" {
            if index < cases.count, cases[index].0 == "native production clipboard byte boundaries" {
                let sentinel = "BOUNDARY-SENTINEL-\(boundaryRequestCount)"
                guard BlockCopyBridge.write(sentinel, to: mathPasteboard) else { fatalError("Boundary sentinel write failed") }
                boundaryCopyBridge.handle(message, generation: "boundary", enabled: true, pasteboard: mathPasteboard)
                if boundaryRequestCount < 6 {
                    let delta = [-1, 0, 1][boundaryRequestCount % 3]
                    let prefix = boundaryRequestCount < 3 ? "" : "中文 😀\t\n"
                    let expected = delta > 0 ? sentinel : prefix + String(repeating: "x", count: 4 * 1024 * 1024 + delta - prefix.utf8.count)
                    guard mathPasteboard.string(forType: .string) == expected else { fatalError("Native boundary pasteboard mismatch") }
                } else {
                    guard mathPasteboard.string(forType: .string) == sentinel else { fatalError("Stale request changed clipboard") }
                }
                boundaryRequestCount += 1
                return
            }
            if failNextMathCopy, let body = message.body as? [String: Any],
               let id = body["id"] as? String, let generation = body["generation"] as? String {
                failNextMathCopy = false
                webView.callAsyncJavaScript("window.blockCopyResult(id, generation, false)", arguments: ["id":id,"generation":generation], in: nil, in: .page) { _ in }
                return
            }
            mathCopyBridge.handle(message, generation: "math-keyboard", enabled: true, pasteboard: mathPasteboard)
            return
        }
        if message.name == "selectionCopy" {
            sourceCopyBridge.handle(message, generation: "source-copy-probe", enabled: true, pasteboard: mathPasteboard)
            let expected = "lpha" + String(repeating: "\n", count: sourceCopyRequestCount < 2 ? 2 : 3) + "bet"
            guard mathPasteboard.string(forType: .string) == expected else { fatalError("Source selection pasteboard mismatch") }
            sourceCopyRequestCount += 1
            return
        }
        if message.name == "nativeMathKey", let key = message.body as? String, let window = focusWindow {
            if key == "narrow" || key == "restore-size" {
                let narrow = key == "narrow"
                window.setContentSize(NSSize(width: narrow ? 320 : 800, height: 600))
                webView.pageZoom = narrow ? 2 : 1
                return
            }
            guard ["space", "enter", "right", "failed-space"].contains(key) else { exit(1) }
            if key == "failed-space" { failNextMathCopy = true }
            let space = key == "space" || key == "failed-space"
            let characters = space ? " " : key == "right" ? "\u{F703}" : "\r"
            let code: UInt16 = space ? 49 : key == "right" ? 124 : 36
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                for type in [NSEvent.EventType.keyDown, .keyUp] {
                    if let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code) {
                        window.sendEvent(event)
                    }
                }
            }
            return
        }
        if message.name == "errorFeedback", let body = message.body as? [String: Any] { feedbackEvents.append(body); return }
        guard let text = message.body as? String else { return }
        if text.contains("Error") || text.contains("fallback") || text.hasPrefix("TSV 20,000") || text.hasPrefix("COPY performance") || text.hasPrefix("ZOOM metrics") { print(text) }
        if text == "rendererReady" && !started { started = true; next() }
    }
    private func next() {
        if index == cases.count { print("PASS all \(cases.count) real WebKit cases"); exit(0) }
        let (name, js) = cases[index]
        // Each case represents a new document and gets a fresh resource-byte budget.
        imageScheme.allowedFileURLs = imageScheme.allowedFileURLs
        // Send one resize per case so WebKit cannot lay out an intermediate viewport.
        let size: NSSize
        if name.hasPrefix("Reading zoom") || name.hasPrefix("Reading workflow") {
            size = NSSize(width: name.contains("narrow") ? 600 : 1200, height: 800)
        } else if name == "compact feedback focus and text bounds" {
            size = NSSize(width: 480, height: 480)
        } else if name == "wide reading layout" || name == "RTL wide geometry" {
            size = NSSize(width: 1800, height: 900)
        } else if name == "narrow reading layout" || name == "RTL narrow geometry" || name == "block copy narrow RTL geometry" {
            size = NSSize(width: 600, height: 600)
        } else {
            size = NSSize(width: 800, height: 600)
        }
        webView.setFrameSize(size)
        if name == "compact feedback focus and text bounds" || name == "inline math copy controls preserve text spacing" || name == "Quick Look selection scope and lifecycle" || name == "Quick Look follow timed updates" || name == "Progressive commit shows first pages quickly" || name == "block copy delayed visibility and focus" || name == "math native keyboard copy and reference" || (name.hasPrefix("Mermaid body-size") || name.hasPrefix("SVG and Mermaid")) {
            // :focus-within requires an active WebKit page, not just activeElement
            // in the otherwise windowless integration harness.
            guard let policy = TestWindowPolicy(environment: ProcessInfo.processInfo.environment), policy.allowsFocus else {
                fputs("FAIL Environment: foreground test interaction is disabled by window policy\n", stderr); exit(1)
            }
            let window = NSWindow(contentRect: webView.frame, styleMask: [.titled], backing: .buffered, defer: false)
            guard let frame = policy.frame(size: window.frame.size, screens: NSScreen.screens.map { $0.visibleFrame }) else {
                fputs("FAIL Environment: required test display is unavailable or too small for \(name) (\(window.frame.size))\n", stderr); exit(1)
            }
            window.setFrame(frame, display: false)
            previousApplication = NSWorkspace.shared.frontmostApplication
            app.setActivationPolicy(.accessory)
            window.contentView = webView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(webView)
            app.activate(ignoringOtherApps: true)
            focusWindow = window
        }
        let viewportGeometry = """
        const resizeDeadline=performance.now()+1500;
        while ((Math.abs(innerWidth-expectedWidth)>1 || Math.abs(innerHeight-expectedHeight)>1) && performance.now()<resizeDeadline) {
          await new Promise(resolve=>setTimeout(resolve,20));
        }
        if(Math.abs(innerWidth-expectedWidth)>1 || Math.abs(innerHeight-expectedHeight)>1)throw new Error('WebKit viewport did not settle: '+innerWidth+'x'+innerHeight+' expected '+expectedWidth+'x'+expectedHeight);
        if (needsFocus) {
          const focusDeadline=performance.now()+2000;
          while(!document.hasFocus() && performance.now()<focusDeadline)await new Promise(resolve=>setTimeout(resolve,20));
          if(!document.hasFocus())throw new Error('Foreground WebKit document did not receive focus');
        }
        const viewportRect = (() => {
          const probe=document.createElement('span');
          probe.style.cssText='position:fixed;left:0;top:0;width:100px;visibility:hidden;zoom:2;font:16px monospace';
          probe.textContent='MMMM';
          document.body.append(probe);
          const sample=document.createRange();sample.selectNodeContents(probe);
          const zoomedRange=sample.getBoundingClientRect().width;
          const legacyElementRects=probe.getBoundingClientRect().width<150;
          probe.style.zoom='1';
          const legacyRangeRects=zoomedRange<sample.getBoundingClientRect().width*1.5;
          probe.remove();
          return function(target) {
            const box=target.getBoundingClientRect();
            const node=target instanceof Range ? target.commonAncestorContainer.parentElement : target;
            const root=node.closest('#markdown-preview');
            const zoom=(target instanceof Range ? legacyRangeRects : legacyElementRects) && root ? Number(root.style.zoom)||1 : 1;
            return new DOMRect((box.x+scrollX)*zoom-scrollX,(box.y+scrollY)*zoom-scrollY,box.width*zoom,box.height*zoom);
          }
        })();
        """
        webView.callAsyncJavaScript(viewportGeometry + "\n" + js, arguments: ["strictTiming": ProcessInfo.processInfo.environment["CI"] == nil, "needsFocus":focusWindow != nil, "expectedWidth":size.width, "expectedHeight":size.height, "imageBase": CommandLine.arguments[2], "svgMarkdown": svgMarkdown, "svgImageData": svgImageData, "sizingSVGData": sizingSVGData], in: nil, in: .page) { result in
            switch result {
            case .success(let value) where value as? Bool == true:
                if name == "native production clipboard byte boundaries", self.boundaryRequestCount != 7 {
                    print("FAIL boundary requests did not traverse native bridge"); exit(1)
                }
                if name == "math native keyboard copy and reference" {
                    guard self.mathPasteboard.string(forType: .string) == #"\(\frac{x}{2}\)"# else { print("FAIL mathematical clipboard source"); exit(1) }
                    self.mathPasteboard.releaseGlobally()
                }
                if name == "contextual feedback bridge" {
                    let reports = self.feedbackEvents.filter { $0["action"] as? String == "inspect" }
                    guard reports.count == 1, reports[0]["kind"] as? String == "mermaid",
                          reports[0]["generation"] as? String == "11111111-1111-1111-1111-111111111111",
                          !String(describing: self.feedbackEvents).contains("SAMPLE-DO-NOT-INCLUDE") else { print("FAIL feedback payload or stale action"); exit(1) }
                }
                if (name == "compact feedback focus and text bounds" && ProcessInfo.processInfo.environment["FLUX_WEBKIT_SNAPSHOT_DIR"] == nil) || name == "inline math copy controls preserve text spacing" || name == "Quick Look follow timed updates" || name == "Progressive commit shows first pages quickly" || name == "Quick Look selection scope and lifecycle" || name == "block copy delayed visibility and focus" || name == "math native keyboard copy and reference" || (name.hasPrefix("Mermaid body-size") || name.hasPrefix("SVG and Mermaid")) {
                    self.focusWindow?.contentView = nil
                    self.focusWindow?.orderOut(nil)
                    self.focusWindow = nil
                    self.previousApplication?.activate(options: [.activateIgnoringOtherApps])
                    app.setActivationPolicy(.prohibited)
                }
                if (name == "compact feedback focus and text bounds" || name == "compact feedback hover collision"), let directory = ProcessInfo.processInfo.environment["FLUX_WEBKIT_SNAPSHOT_DIR"] {
                    self.webView.takeSnapshot(with: nil) { image, error in
                        guard let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { print("FAIL feedback snapshot: \(String(describing: error))"); exit(1) }
                        do {
                            let folder = URL(fileURLWithPath: directory)
                            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                            try png.write(to: folder.appendingPathComponent(name == "compact feedback hover collision" ? "feedback-hover.png" : "feedback-focus.png"))
                        } catch { print("FAIL feedback snapshot save: \(error)"); exit(1) }
                        self.focusWindow?.contentView = nil; self.focusWindow?.orderOut(nil); self.focusWindow = nil
                        self.previousApplication?.activate(options: [.activateIgnoringOtherApps]); app.setActivationPolicy(.prohibited)
                        print("PASS \(name) with snapshot"); self.index += 1; self.next()
                    }
                    return
                }
                print("PASS \(name)"); self.index += 1; self.next()
            default: print("FAIL \(name): \(result)"); exit(1)
            }
        }
    }
}
let integration = RendererIntegration()
integration.run()
app.run()
