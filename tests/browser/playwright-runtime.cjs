'use strict';
const path=require('node:path');
const os=require('node:os');
const candidates=[process.env.PLAYWRIGHT_MODULE,'playwright',path.join(os.homedir(),'.cache','codex-runtimes','codex-primary-runtime','dependencies','node','node_modules','playwright')].filter(Boolean);
let runtime;
for(const candidate of candidates){
 try{runtime=require(candidate);break}catch(error){if(error.code!=='MODULE_NOT_FOUND')throw error}
}
if(!runtime)throw new Error('Install Playwright (npm install --no-save playwright), or set PLAYWRIGHT_MODULE to its module directory.');
module.exports=runtime;
