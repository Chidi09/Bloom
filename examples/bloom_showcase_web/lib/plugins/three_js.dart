import 'dart:js_interop';
import 'dart:math' as math;
import 'package:web/web.dart' as web;

@JS('THREE.Scene')
extension type ThreeScene._(JSObject _) implements JSObject {
  external ThreeScene();
  external void add(JSObject object);
}

@JS('THREE.PerspectiveCamera')
extension type ThreeCamera._(JSObject _) implements JSObject {
  external ThreeCamera(double fov, double aspect, double near, double far);
  external JSObject get position;
  external set aspect(double value);
  external void updateProjectionMatrix();
}

@JS('THREE.WebGLRenderer')
extension type ThreeRenderer._(JSObject _) implements JSObject {
  external ThreeRenderer(JSObject options);
  external void setSize(double width, double height);
  external void setPixelRatio(double pixelRatio);
  external void render(JSObject scene, JSObject camera);
}

@JS('THREE.IcosahedronGeometry')
extension type ThreeIcosahedronGeometry._(JSObject _) implements JSObject {
  external ThreeIcosahedronGeometry(double radius, int detail);
}

@JS('THREE.TorusGeometry')
extension type ThreeTorusGeometry._(JSObject _) implements JSObject {
  external ThreeTorusGeometry(double radius, double tube, int radialSegments, int tubularSegments);
}

@JS('THREE.MeshBasicMaterial')
extension type ThreeMeshBasicMaterial._(JSObject _) implements JSObject {
  external ThreeMeshBasicMaterial(JSObject options);
}

@JS('THREE.Mesh')
extension type ThreeMesh._(JSObject _) implements JSObject {
  external ThreeMesh(JSObject geometry, JSObject material);
  external JSObject get rotation;
}

@JS('THREE.Group')
extension type ThreeGroup._(JSObject _) implements JSObject {
  external ThreeGroup();
  external void add(JSObject object);
  external JSObject get rotation;
}

class ThreeHeroScene {
  final web.HTMLCanvasElement canvas;
  bool _running = false;
  double _mouseX = 0;
  double _mouseY = 0;

  ThreeHeroScene(this.canvas);

  void init() {
    try {
      final rect = canvas.getBoundingClientRect();
      final width = rect.width > 0 ? rect.width.toDouble() : (canvas.clientWidth > 0 ? canvas.clientWidth.toDouble() : 900.0);
      final height = rect.height > 0 ? rect.height.toDouble() : (canvas.clientHeight > 0 ? canvas.clientHeight.toDouble() : 600.0);

      final scene = ThreeScene();
      final camera = ThreeCamera(45, width / height, 0.1, 1000);
      (camera.position as dynamic).z = 6.0;

      final opts = <String, dynamic>{
        'canvas': canvas,
        'alpha': true,
        'antialias': true,
      }.jsify() as JSObject;

      final renderer = ThreeRenderer(opts);
      renderer.setSize(width, height);
      renderer.setPixelRatio(web.window.devicePixelRatio.toDouble());

      final group = ThreeGroup();
      scene.add(group);

      // 1. Primary Glowing Wireframe Icosahedron
      final geo = ThreeIcosahedronGeometry(1.8, 2);
      final matOpts = <String, dynamic>{
        'color': 0x6366F1,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.45,
      }.jsify() as JSObject;
      final mat = ThreeMeshBasicMaterial(matOpts);
      final mesh = ThreeMesh(geo, mat);
      group.add(mesh);

      // 2. Secondary Inner Gyroscope Core
      final innerGeo = ThreeIcosahedronGeometry(1.1, 1);
      final innerMatOpts = <String, dynamic>{
        'color': 0x8B5CF6,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.30,
      }.jsify() as JSObject;
      final innerMat = ThreeMeshBasicMaterial(innerMatOpts);
      final innerMesh = ThreeMesh(innerGeo, innerMat);
      group.add(innerMesh);

      // 3. Ambient Orbital Ring
      final ringGeo = ThreeTorusGeometry(2.4, 0.015, 16, 100);
      final ringMatOpts = <String, dynamic>{
        'color': 0x06B6D4,
        'wireframe': true,
        'transparent': true,
        'opacity': 0.20,
      }.jsify() as JSObject;
      final ringMat = ThreeMeshBasicMaterial(ringMatOpts);
      final ringMesh = ThreeMesh(ringGeo, ringMat);
      (ringMesh.rotation as dynamic).x = math.pi / 3;
      group.add(ringMesh);

      _running = true;

      // Mouse Parallax
      web.window.onmousemove = (web.MouseEvent e) {
        _mouseX = (e.clientX / web.window.innerWidth) * 2 - 1;
        _mouseY = -(e.clientY / web.window.innerHeight) * 2 + 1;
      }.toJS;

      void animate(double time) {
        if (!_running) return;

        // Continuous smooth rotation
        (mesh.rotation as dynamic).x += 0.002;
        (mesh.rotation as dynamic).y += 0.0035;
        (innerMesh.rotation as dynamic).x -= 0.003;
        (innerMesh.rotation as dynamic).y -= 0.0045;
        (ringMesh.rotation as dynamic).z += 0.0015;

        // Parallax easing
        (group.rotation as dynamic).y += (_mouseX * 0.4 - (group.rotation as dynamic).y) * 0.05;
        (group.rotation as dynamic).x += (-_mouseY * 0.4 - (group.rotation as dynamic).x) * 0.05;

        renderer.render(scene, camera);
        web.window.requestAnimationFrame(animate.toJS);
      }

      web.window.requestAnimationFrame(animate.toJS);

      // Handle Resize
      web.window.onresize = (web.Event e) {
        if (!_running) return;
        final newRect = canvas.getBoundingClientRect();
        final newW = newRect.width > 0 ? newRect.width.toDouble() : canvas.clientWidth.toDouble();
        final newH = newRect.height > 0 ? newRect.height.toDouble() : canvas.clientHeight.toDouble();
        if (newW > 0 && newH > 0) {
          camera.aspect = newW / newH;
          camera.updateProjectionMatrix();
          renderer.setSize(newW, newH);
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
