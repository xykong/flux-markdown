const { test } = require('node:test');
const assert = require('node:assert/strict');
const { reconcile } = require('../feishu-upstream-watch.cjs');
const issue = { number: 5412, title: 'Hosting request', state: 'open', labels: [{name:'hosting-request'}], html_url:'https://github.com/jenkins-infra/repository-permissions-updater/issues/5412' };
const comment = { id: 1, body:'Review complete <at user_id="all">', updated_at:'2026-11-12T00:00:00Z', user:{login:'reviewer'}, html_url:issue.html_url+'#issuecomment-1' };
test('baseline skips history; new comments notify once and preserve links', async () => {
  const state = {}; const sent=[];
  await reconcile(state, issue, [], async m=>sent.push(m), ()=>{});
  assert.equal(sent.length,0);
  await reconcile(state, issue, [comment], async m=>sent.push(m), ()=>{});
  assert.equal(sent.length,1);
  assert.match(sent[0], /#issuecomment-1/);
  assert.doesNotMatch(sent[0], /<at/);
  await reconcile(state, issue, [comment], async m=>sent.push(m), ()=>{});
  assert.equal(sent.length,1);
});
test('status, labels and edited comments trigger updates', async () => {
  const state={}; const sent=[]; const send=async m=>sent.push(m);
  await reconcile(state, issue, [comment], send, ()=>{});
  await reconcile(state, {...issue,state:'closed',labels:[]}, [{...comment,updated_at:'later',body:'edited'}], send, ()=>{});
  assert.equal(sent.length,2);
  assert.match(sent[0],/closed/);
  assert.match(sent[1],/edited/);
});
test('unknown delivery persists pending and blocks automatic resend', async () => {
  const state={}; let saved;
  await reconcile(state,issue,[],async()=>{},()=>{});
  await assert.rejects(reconcile(state,issue,[comment],async()=>{throw Error('unknown');},()=>{saved=structuredClone(state);}),/unknown/);
  assert.equal(saved.pending,comment.html_url);
  await assert.rejects(reconcile(state,issue,[comment],async()=>assert.fail('resent'),()=>{}),/pending/);
});
