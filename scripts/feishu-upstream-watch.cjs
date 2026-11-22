const { buildMessage, sendMessage } = require('./feishu-notify.cjs');
const fs = require('node:fs');
const clean = value => String(value || '').replace(/</g, '＜').replace(/>/g, '＞');
const metadata = issue => JSON.stringify([issue.title, issue.state, issue.state_reason, issue.labels.map(l=>l.name).sort()]);

async function reconcile(state, issue, comments, send, save) {
  if (state.pending) throw new Error(`Delivery pending manual verification: ${state.pending}`);
  if (!state.version) {
    Object.assign(state, { version:1, metadata:metadata(issue), comments:Object.fromEntries(comments.map(c=>[c.id,c.updated_at])) });
    save();
    return;
  }
  if (state.version !== 1) throw new Error('Unsupported cursor version');
  async function deliver(url, text, advance) {
    state.pending=url;
    save();
    await send(clean(text));
    advance();
    delete state.pending;
    save();
  }
  if (state.metadata !== metadata(issue)) {
    await deliver(issue.html_url, `Parameter Foundry 上游申请有更新\n${issue.title}\n状态：${issue.state}\n标签：${issue.labels.map(l=>l.name).join(', ')}\n${issue.html_url}`, ()=>{ state.metadata=metadata(issue); });
  }
  for (const c of comments) {
    if (state.comments[c.id] === c.updated_at) continue;
    await deliver(c.html_url, `Parameter Foundry 上游申请 · ${state.comments[c.id] ? '评论已编辑' : '新评论'}\n${c.user?.login || 'GitHub'}\n${String(c.body || '').slice(0,700)}\n${c.html_url}`, ()=>{state.comments[c.id]=c.updated_at;});
  }
}

async function run({github, context, core}) {
  const target={owner:'jenkins-infra',repo:'repository-permissions-updater',issue_number:5412};
  const issue=(await github.rest.issues.get(target)).data;
  const comments=await github.paginate(github.rest.issues.listComments,{...target,per_page:100});
  const file='.upstream-watch/state.json';
  fs.mkdirSync('.upstream-watch',{recursive:true});
  const state=fs.existsSync(file) ? JSON.parse(fs.readFileSync(file,'utf8')) : {};
  const save=()=>fs.writeFileSync(file,JSON.stringify(state));
  const send=async text=>sendMessage(buildMessage('issue_comment',{
    repository:{full_name:'xykong/flux-markdown · Parameter Foundry upstream'},
    issue:{number:5412,title:issue.title}, action:'created',
    sender:{login:'upstream-watch'},comment:{body:text,html_url:text.split('\n').at(-1)}
  },process.env.FEISHU_MENTION_OPEN_ID),{url:process.env.FEISHU_WEBHOOK_URL,secret:process.env.FEISHU_WEBHOOK_SECRET});
  if (context.payload.inputs?.test_connection === 'true') {
    await send(`Parameter Foundry 上游通知连接测试：仅监控 #5412，新评论和状态变化将转发到本群。\n${issue.html_url}`);
  }
  const baseline=!state.version;
  await reconcile(state,issue,comments,send,save);
  core.info(baseline ? 'Baseline saved; historical messages were not forwarded.' : 'Upstream cursor checked and saved.');
}
module.exports={reconcile,run};
