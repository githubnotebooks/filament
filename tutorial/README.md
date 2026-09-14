# Filament 学习路径

面向在 Linux 桌面(本项目 devshell)上学习和调试 Filament 的入门指南。
构建命令见根目录 `linux_build.sh`(`-t` 启用 fgviewer,`-d` 启用 matdbg)。

## 第一步:先跑起来再读(约半天)

从 `samples/` 入手,梯度很友好,按以下顺序跑:

| Sample | 学到什么 |
| --- | --- |
| `hellotriangle` | 最基本的生命周期:`Engine::create` → `Renderer` → `Scene`/`View` → `swapBuffers` |
| `hellopbr` | 加上材质、灯光、IBL |
| `gltf_viewer` | 接近真实使用方式;`third_party/` 里的 gltf_loader 也是可读的样板代码 |

## 第二步:读两份核心文档(最重要)

都在 `docs/main/` 下,是本项目最好的资料:

- `filament.html` —— 架构文档,重点读 "The renderer" 和 "Engine" 章节,
  搞清楚 **Engine / Renderer / View / Scene / Camera / Material 六个概念的
  一次性与每帧生命周期**,整个 API 设计就通了。
- `materials.html` —— 材质系统,讲清楚 `.mat` 文件 → `matc` 编译 → shader
  的整条链路。

## 第三步:顺着一条渲染帧读源码

1. 入口:`filament/src/Renderer.cpp` 的 `beginFrame` / `render` / `endFrame`
2. `filament/src/FrameGraph.cpp` —— 帧图是 Filament 最有特色的设计
   (资源声明式管理、自动剔除无用的 render pass),配套注释很密,值得精读
3. `filament/backend/` —— Driver 抽象层,对比 OpenGL 和 Vulkan 两个后端
   如何实现同一接口

## 第四步:按需深入周边

- `libs/utils/` —— JobSystem、ECS 等基础设施
- `libs/filabridge/` —— CPU↔GPU 数据桥
- `libs/matdbg` + fgviewer —— 调试工具,边学边用:
  对着一帧的 frame graph 看代码,理解最快

## 阅读建议

- 不要从 utility 代码或 backend 抽象开始读:filament 内部模板和抽象层
  用得很重(backend 里全是 CRTP 和空基类优化),容易劝退。
- 推荐 `samples/` + `Renderer.cpp` 的调用链入手,会顺很多。
- 调试时配合 fgviewer(`-t` 构建)观察实际生效的 render pass。
