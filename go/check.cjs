const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const script=fs.readFileSync(__dirname+'/redirect.js','utf8');
for(const [search,expected] of [['?u=1001','https://t.xykong.cc/p/1001'],['?u=9999',null],['?u=1001&u=1001',null],['?u=https://evil.test',null],['?u=1001&next=https://evil.test','https://t.xykong.cc/p/1001']]) {
 let target=null;vm.runInNewContext(script,{URLSearchParams,location:{search,replace:v=>target=v}});assert.equal(target,expected);
}
console.log('PASS: fixed numeric mapping, unknown/duplicate rejection, no open redirect');
