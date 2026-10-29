# 网页发布

试玩地址：https://grrreymane.github.io/taixu-yanwu/

源码和完整游戏资源保留在同一仓库。网页使用 GitHub Pages，通过 Actions 部署已验证的 Godot 导出包。导出文件不重复提交到 Git 历史。

## 更新试玩版本

1. 运行 `build-web.ps1`，检查本地试玩与存档行为。
2. 将 `build/web/` 中不以 `.gz` 结尾的文件打包成 `site.tar.gz`；压缩包根目录必须直接包含 `index.html`、`index.pck`、`index.wasm` 等文件，而非多一层目录。
3. 在当前仓库创建对应源码版本的 Release，将压缩包作为附件上传。
4. 在 Actions 中打开 **Publish playable web game**，选择 **Run workflow**，填写 Release 标签。
5. 等待成功后访问试玩地址，检查启动、战斗和存档。回退时重新部署之前的 Release 标签即可。

Pages 设置使用 GitHub Actions。导出采用 Compatibility 渲染器、关闭线程，不需要跨源隔离响应头。资源路径保持相对路径，以兼容项目子目录。

## 存档与下载

当前完整导出约 160 MB。首次进入需等待资源下载，浏览器可能缓存资源。存档属于当前站点、当前浏览器，本地试玩和线上试玩的存档互不相通。尚无账号同步或线上排行榜。

## 历史清理后的本地副本

仓库历史已在首次公开前清理个人目录。其他旧克隆建议重新克隆；不要把旧分支合并回来，以免重新带入清理过的历史。本机历史备份不属于发布内容。
