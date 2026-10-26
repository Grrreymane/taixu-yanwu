import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'build/web');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.svg':'image/svg+xml','.json':'application/json','.ttf':'font/ttf','.woff2':'font/woff2'};
http.createServer((req,res)=>{
 try{
  const relative=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/+/, '')||'index.html';
  const file=path.resolve(root,relative);
  if(!file.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404);res.end('Not found');return;}
  const gz=file+'.gz';
  const zipped=/\bgzip\b/.test(req.headers['accept-encoding']||'')&&fs.existsSync(gz)&&fs.statSync(gz).mtimeMs>=fs.statSync(file).mtimeMs;
  const target=zipped?gz:file;
  const headers={'Content-Type':mime[path.extname(file)]||'application/octet-stream','Cache-Control':'no-cache','Content-Length':fs.statSync(target).size,'Vary':'Accept-Encoding'};
  if(zipped)headers['Content-Encoding']='gzip';
  res.writeHead(200,headers);
  const stream=fs.createReadStream(target);
  stream.on('error',error=>{console.error('File read failed:',error.message);res.destroy();});
  stream.pipe(res);
 }catch{res.writeHead(400);res.end('Bad request');}
}).listen(4187,'127.0.0.1',()=>console.log('Godot 符华网页试玩 http://127.0.0.1:4187/'));
