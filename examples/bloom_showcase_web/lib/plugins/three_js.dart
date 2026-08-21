import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('THREE.Scene')
external JSObject _createScene();

@JS('THREE.PerspectiveCamera')
external JSObject _createCamera(double fov, double aspect, double near, double far);

@JS('THREE.WebGLRenderer')
external JSObject _createRenderer(JSObject options);

@JS('THREE.IcosahedronGeometry')
external JSObject _createIcosahedronGeometry(double radius, int detail);

@JS('THREE.MeshBasicMaterial')
external JSObject _createMeshBasicMaterial(JSObject options);

@JS('THREE.Mesh')
external JSObject _createMesh(JSObject geometry, JSObject material);

class ThreeHeroScene {
  final web.HTMLCanvasElement canvas;
  bool _running = false;

  ThreeHeroScene(this.canvas);

  void init() {
    try {
      final width = canvas.clientWidth > 0 ? canvas.clientWidth.toDouble() : 800.0;
      final height = canvas.clientHeight > 0 ? canvas.clientHeight.toDouble() : 500.0;

      final scene = _createScene();
      final camera = _createCamera(45, width / height, 0.1, 1000);
      (camera as dynamic).position.z = 5.0;

      final opts = <String, dynamic>{
        'canvas': canvas,
        'alpha': true,
        'antialias': true,
      }.jsify() as JSObject;

      final renderer = _createRenderer(opts);
      (renderer as dynamic).setSize(width, height);
      (renderer as dynamic).setPixelRatio(web.window.devicePixelRatio.toDouble());

      // 1. Glowing wireframe icosahedron
      final geo = _createIcosahedronGeometry(1.6, 2);
      final matOpts = <String, dynamic>{
        'color': 0x6366F1,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.35,
      }.jsify() as JSObject;
      final mat = _createMeshBasicMaterial(matOpts);
      final mesh = _createMesh(geo, mat);
      (scene as dynamic).add(mesh);

      // 2. Core inner mesh
      final innerGeo = _createIcosahedronGeometry(0.9, 1);
      final innerMatOpts = <String, dynamic>{
        'color': 0x8B5CF6,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.20,
      }.jsify() as JSObject;
      final innerMat = _createMeshBasicMaterial(innerMatOpts);
      final innerMesh = _createMesh(innerGeo, innerMat);
      (scene as dynamic).add(innerMesh);

      _running = true;

      void animate(double time) {
        if (!_running) return;
        (mesh as dynamic).rotation.x += 0.003;
        (mesh as dynamic).rotation.y += 0.005;
        (innerMesh as dynamic).rotation.x -= 0.004;
        (innerMesh as dynamic).rotation.y -= 0.006;

        (renderer as dynamic).render(scene, camera);
        web.window.requestAnimationFrame(animate.toJS);
      }

      web.window.requestAnimationFrame(animate.toJS);

      // Handle Resize
      web.window.onresize = (web.Event e) {
        if (!_running) return;
        final newW = canvas.clientWidth.toDouble();
        final newH = canvas.clientHeight.toDouble();
        if (newW > 0 && newH > 0) {
          (camera as dynamic).aspect = newW / newH;
          (camera as dynamic).updateProjectionMatrix();
          (renderer as dynamic).setSize(newW, newH);
        }
      }.toJS;
    } catch (_) {
      // Graceful fallback if WebGL or Three.js fails
    }
  }

  void dispose() {
    _running = false;
  }
}
