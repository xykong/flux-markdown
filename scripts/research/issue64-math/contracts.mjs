import fs from 'node:fs';
import {mathjax} from '@mathjax/src/js/mathjax.js';
import {TeX} from '@mathjax/src/js/input/tex.js';
import {SVG} from '@mathjax/src/js/output/svg.js';
import {liteAdaptor} from '@mathjax/src/js/adaptors/liteAdaptor.js';
import {RegisterHTMLHandler} from '@mathjax/src/js/handlers/html.js';
import {SerializedMmlVisitor} from '@mathjax/src/js/core/MmlTree/SerializedMmlVisitor.js';
import '@mathjax/src/js/util/asyncLoad/esm.js';
import '@mathjax/src/js/input/tex/base/BaseConfiguration.js';
import '@mathjax/src/js/input/tex/ams/AmsConfiguration.js';
import '@mathjax/src/js/input/tex/newcommand/NewcommandConfiguration.js';
const adaptor=liteAdaptor();RegisterHTMLHandler(adaptor);const visitor=new SerializedMmlVisitor();
const scenarios=[
 ['automatic-and-explicit',String.raw`\[x=1\tag{1}\label{explicit}\]\begin{equation}y=2\label{auto}\end{equation}\(\eqref{explicit}+\eqref{auto}\)`],
 ['untagged-label',String.raw`\[x=1\label{untagged}\]\(\eqref{untagged}\)`],
 ['failed-target',String.raw`\[x=1\tag{A}\label{failed}\unknownCommand\]\(\eqref{failed}\)`],
 ['labels-with-spaces',String.raw`\[x=1\tag{A}\label{a b}\]\[x=2\tag{B}\label{a_b}\]\(\eqref{a b}+\eqref{a_b}\)`],
 ['prototype-labels',String.raw`\[x=1\tag{A}\label{constructor}\]\(\eqref{constructor}\)`],
 ['unicode-labels',String.raw`\[x=1\tag{A}\label{公式:α/1%}\]\(\eqref{公式:α/1%}\)`],
 ['tag-star',String.raw`\[x=1\tag*{B}\label{star}\]\(\ref{star}+\eqref{star}\)`],
 ['macro-definition',String.raw`\(\newcommand{\shared}{42}\shared\)`],
 ['macro-fresh-document',String.raw`\(\shared\)`]
];
const results=[];
for(const [name,input] of scenarios){
  const errors=[];const tex=new TeX({packages:['base','ams','newcommand'],tags:'ams',formatError(jax,e){errors.push(e.message);return jax.formatError(e)}});
  const doc=mathjax.document(input,{InputJax:tex,OutputJax:new SVG({fontCache:'local'})});
  try{await doc.renderPromise();results.push({name,input,errors,labels:tex.parseOptions.tags.allLabels,mml:[...doc.math].map(m=>visitor.visitTree(m.root))});}
  catch(e){results.push({name,input,errors,uncaught:String(e)})}
}
fs.writeFileSync(new URL('contract-results.json',import.meta.url),JSON.stringify(results,null,2));
for(const r of results)console.log(JSON.stringify({name:r.name,errors:r.errors,labels:r.labels,uncaught:r.uncaught}));
