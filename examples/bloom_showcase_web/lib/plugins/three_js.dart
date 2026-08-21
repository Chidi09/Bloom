import 'dart:js_interop';
import 'dart:math' as math;
import 'package:web/web.dart' as web;

@JS('THREE.Scene')
external JSObject _createScene();

@JS('THREE.PerspectiveCamera')
external JSObject _createCamera(double fov, double aspect, double near, double far);

@JS('THREE.WebGLRenderer')
external JSObject _createRenderer(JSObject options);

@JS('THREE.IcosahedronGeometry')
external JSObject _createIcosahedronGeometry(double radius, int detail);

@JS('THREE.TorusGeometry')
external JSObject _createTorusGeometry(double radius, double tube, int radialSegments, int tubularSegments);

@JS('THREE.MeshBasicMaterial')
external JSObject _createMeshBasicMaterial(JSObject options);

@JS('THREE.Mesh')
external JSObject _createMesh(JSObject geometry, JSObject material);

@JS('THREE.Group')
external JSObject _createGroup();

class ThreeHeroScene {
  final web.HTMLCanvasElement canvas;
  bool _running = false;
  double _mouseX = 0;
  double _mouseY = 0;

  ThreeHeroScene(this.canvas);

  void init() {
    try {
      final width = canvas.clientWidth > 0 ? canvas.clientWidth.toDouble() : 900.0;
      final height = canvas.clientHeight > 0 ? canvas.clientHeight.toDouble() : 600.0;

      final scene = _createScene();
      final camera = _createCamera(45, width / height, 0.1, 1000);
      (camera as dynamic).position.z = 6.0;

      final opts = <String, dynamic>{
        'canvas': canvas,
        'alpha': true,
        'antialias': true,
      }.jsify() as JSObject;

      final renderer = _createRenderer(opts);
      (renderer as dynamic).setSize(width, height);
      (renderer as dynamic).setPixelRatio(web.window.devicePixelRatio.toDouble());

      final group = _createGroup();
      (scene as dynamic).add(group);

      // 1. Primary Glowing Wireframe Icosahedron
      final geo = _createIcosahedronGeometry(1.8, 2);
      final matOpts = <String, dynamic>{
        'color': 0x6366F1,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.40,
      }.jsify() as JSObject;
      final mat = _createMeshBasicMaterial(matOpts);
      final mesh = _createMesh(geo, mat);
      (group as dynamic).add(mesh);

      // 2. Secondary Inner Gyroscope Core
      final innerGeo = _createIcosahedronGeometry(1.1, 1);
      final innerMatOpts = <String, dynamic>{
        'color': 0x8B5CF6,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.25,
      }.jsify() as JSObject;
      final innerMat = _createMeshBasicMaterial(innerMatOpts);
      final innerMesh = _createMesh(innerGeo, innerMat);
      (group as dynamic).add(innerMesh);

      // 3. Ambient Orbital Rings
      final ringGeo = _createTorusGeometry(2.4, 0.015, 16, 100);
      final ringMatOpts = <String, dynamic>{
        'color': 0x06B6D4,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.15,
      }.jsify() as JSObject;
      final ringMat = _createMeshBasicMaterial(ringMatOpts);
      final ringMesh = _createMesh(ringGeo, ringMat);
      (ringMesh as dynamic).rotation.x = math.pi / 3;
      (group as dynamic).add(ringMesh);

      _running = true;

      // Mouse Parallax
      web.window.onmousemove = (web.MouseEvent e) {
        _mouseX = (e.clientX / web.window.innerWidth) * 2 - 1;
        _mouseY = -(e.clientY / web.window.innerHeight) * 2 + 1;
      }.toJS;

      void animate(double time) {
        if (!_running) return;

        // Continuous smooth rotation
        (mesh as dynamic).rotation.x += 0.002;
        (mesh as dynamic).rotation.y += 0.0035;
        (innerMesh as dynamic).rotation.x -= 0.003;
        (innerMesh as dynamic).rotation.y -= 0.0045;
        (ringMesh as dynamic).rotation.z += 0.0015;

        // Parallax easing
        (group as dynamic).rotation.y += (_mouseX * 0.4 - (group as dynamic).rotation.y) * 0.05;
        (group as dynamic).rotation.x += (-_mouseY * 0.4 - (group as dynamic).rotation.x) * 0.05;

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
      // Graceful fallback
    }
  }

  void dispose() {
    _running = false;
  }
}
