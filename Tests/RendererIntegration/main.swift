import AppKit
import WebKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
final class RendererIntegration: NSObject, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var focusWindow: NSWindow?
    private var previousApplication: NSRunningApplication?
    private let mathPasteboard = NSPasteboard.withUniqueName()
    private let mathCopyBridge = BlockCopyBridge()
    private var failNextMathCopy = false
    private var started = false
    private var index = 0
    private var feedbackEvents: [[String: Any]] = []
    private var cases: [(String, String)] = [
        ("block copy delayed visibility and focus", """
        await window.renderMarkdown('```\\nhello\\n```',{context:'app',showCopyButtons:true});
        const nativeFocusDeadline=performance.now()+4000;
        while(!document.hasFocus() && performance.now()<nativeFocusDeadline)await new Promise(r=>setTimeout(r,50));
        if(!document.hasFocus())throw new Error('Environment: native test window did not become active');
        const tools=document.querySelector('.block-copy-tools'),button=tools.querySelector('button');
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
        window.renderSource('a\\tb\\npartial','dark',undefined,{format:'tsv',isTruncated:true});
        if(!document.querySelector('.tsv-truncated'))return false;
        await window.renderMarkdown('# Restored',{uiLanguage:'en'});
        return document.querySelector('h1').textContent==='Restored'&&!document.querySelector('.tsv-truncated');
        """),
        ("contextual feedback bridge", """
        window.setFeedbackGeneration('11111111-1111-1111-1111-111111111111');
        await window.renderMarkdown('```mermaid\\nSAMPLE-DO-NOT-INCLUDE ! invalid\\n```');
        await new Promise(resolve=>setTimeout(resolve,20));
        const button=document.querySelector('.mermaid-error [data-feedback-action="report"]');
        if(!button)return false;
        button.click();
        const exported=window.exportHTML();
        window.setFeedbackGeneration('22222222-2222-2222-2222-222222222222');
        button.click();
        return !exported.includes('data-feedback-action=');
        """),
        ("passive HTML", "await window.renderMarkdown('<img src=\"missing.png\" onerror=\"window.pwned=true\"><details><summary>ok</summary></details>'); return !document.querySelector('[onerror]') && !window.pwned && !!document.querySelector('details');"),
        ("new render wins", "const a=window.renderMarkdown('# OLD\\n\\n$x$'); const b=window.renderMarkdown('# NEW',{enableKatex:false}); await Promise.all([a,b]); return document.querySelector('h1').textContent==='NEW';"),
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
    func run() {
        if let filter = ProcessInfo.processInfo.environment["FLUX_WEBKIT_CASE_FILTER"] {
            cases = cases.filter { $0.0.localizedCaseInsensitiveContains(filter) }
            guard !cases.isEmpty else { fputs("FAIL no matching integration cases\n", stderr); exit(1) }
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "logger")
        config.userContentController.add(self, name: "blockCopy")
        config.userContentController.add(self, name: "nativeMathKey")
        config.userContentController.add(self, name: "errorFeedback")
        config.setURLSchemeHandler(RendererBundleSchemeHandler(rootDirectory: URL(fileURLWithPath: CommandLine.arguments[1])), forURLScheme: RendererBundleSchemeHandler.scheme)
        let imageDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
        let imageURL = imageDirectory.appendingPathComponent("pixel.png")
        try! Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==")!.write(to: imageURL)
        let images = LocalSchemeHandler()
        images.baseDirectory = imageDirectory
        let svgURL = imageDirectory.appendingPathComponent("plugin/assets/plugin.svg")
        try! FileManager.default.createDirectory(at: svgURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! #"<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect width="96" height="96" fill="green"/></svg>"#.write(to: svgURL, atomically: true, encoding: .utf8)
        let markdownURL = imageDirectory.appendingPathComponent("issue63.md")
        svgImageData = MarkdownImageDataCollector.collectImageData(from: markdownURL, content: svgMarkdown)
        guard svgImageData["plugin/assets/plugin.svg"] != nil else { fatalError("SVG collector failed") }
        images.allowedFileURLs = MarkdownImageDataCollector.referencedLocalImageURLs(from: markdownURL, content: svgMarkdown).union([imageURL])
        config.setURLSchemeHandler(images, forURLScheme: "local-md")
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.load(URLRequest(url: RendererBundleSchemeHandler.rendererURL()))
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { fputs("FAIL integration timeout\n", stderr); exit(1) }
    }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard RendererBridgePolicy.accepts(message) else { print("FAIL bridge origin"); exit(1) }
        if message.name == "blockCopy" {
            if failNextMathCopy, let body = message.body as? [String: Any],
               let id = body["id"] as? String, let generation = body["generation"] as? String {
                failNextMathCopy = false
                webView.callAsyncJavaScript("window.blockCopyResult(id, generation, false)", arguments: ["id":id,"generation":generation], in: nil, in: .page) { _ in }
                return
            }
            mathCopyBridge.handle(message, generation: "math-keyboard", enabled: true, pasteboard: mathPasteboard)
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
        if text.contains("Error") || text.contains("fallback") || text.hasPrefix("TSV 20,000") || text.hasPrefix("COPY performance") { print(text) }
        if text == "rendererReady" && !started { started = true; next() }
    }
    private func next() {
        if index == cases.count { print("PASS all \(cases.count) real WebKit cases"); exit(0) }
        let (name, js) = cases[index]
        if name == "block copy delayed visibility and focus" || name == "math native keyboard copy and reference" {
            // :focus-within requires an active WebKit page, not just activeElement
            // in the otherwise windowless integration harness.
            previousApplication = NSWorkspace.shared.frontmostApplication
            app.setActivationPolicy(.accessory)
            let window = NSWindow(contentRect: webView.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.contentView = webView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(webView)
            app.activate(ignoringOtherApps: true)
            focusWindow = window
        }
        if name == "wide reading layout" || name == "RTL wide geometry" { webView.setFrameSize(NSSize(width: 1800, height: 900)) }
        if name == "narrow reading layout" || name == "RTL narrow geometry" || name == "block copy narrow RTL geometry" { webView.setFrameSize(NSSize(width: 600, height: 600)) }
        webView.callAsyncJavaScript(js, arguments: ["imageBase": CommandLine.arguments[2], "svgMarkdown": svgMarkdown, "svgImageData": svgImageData], in: nil, in: .page) { result in
            switch result {
            case .success(let value) where value as? Bool == true:
                if name == "math native keyboard copy and reference" {
                    guard self.mathPasteboard.string(forType: .string) == #"\(\frac{x}{2}\)"# else { print("FAIL mathematical clipboard source"); exit(1) }
                    self.mathPasteboard.releaseGlobally()
                }
                if name == "contextual feedback bridge" {
                    let reports = self.feedbackEvents.filter { $0["action"] as? String == "report" }
                    guard reports.count == 1, reports[0]["kind"] as? String == "mermaid",
                          reports[0]["generation"] as? String == "11111111-1111-1111-1111-111111111111",
                          !String(describing: self.feedbackEvents).contains("SAMPLE-DO-NOT-INCLUDE") else { print("FAIL feedback payload or stale action"); exit(1) }
                }
                if name == "block copy delayed visibility and focus" || name == "math native keyboard copy and reference" {
                    self.focusWindow?.contentView = nil
                    self.focusWindow?.orderOut(nil)
                    self.focusWindow = nil
                    self.previousApplication?.activate(options: [.activateIgnoringOtherApps])
                    app.setActivationPolicy(.prohibited)
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
