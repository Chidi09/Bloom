# 24. Repository Pattern & CRUD Contracts

Bloom provides architectural repository contracts that decouple your domain UI and controllers from direct network, database, or mock implementations.

---

## 🏛️ Base `BloomRepository`

`BloomRepository` is the base class for general-purpose API services. It automatically resolves the application's configured `BloomHttpClient` from the active DI container:

```dart
import 'package:bloom_framework/bloom.dart';

class OrderRepository extends BloomRepository {
  Future<OrderSummary> getSummary(String orderId) async {
    final res = await http.get('/orders/$orderId/summary');
    return OrderSummary.fromJson(res);
  }
}
```

---

## 📑 Generic `BloomCrudRepository<T, ID>` Contract

For standard CRUD entities, implement `BloomCrudRepository<T, ID>`:

```dart
abstract class BloomCrudRepository<T, ID> {
  Future<List<T>> findAll();
  Future<T?> findById(ID id);
  Future<T> create(T item);
  Future<T> update(ID id, T item);
  Future<bool> delete(ID id);
}
```

---

## 🛠️ Implementing a Typed Repository

```dart
class ProductRepository implements BloomCrudRepository<Product, String> {
  final BloomHttpClient _http;

  ProductRepository(this._http);

  @override
  Future<List<Product>> findAll() async {
    final list = await _http.get<List<dynamic>>('/products');
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Product?> findById(String id) async {
    final res = await _http.get<Map<String, dynamic>?>('/products/$id');
    return res != null ? Product.fromJson(res) : null;
  }

  @override
  Future<Product> create(Product item) async {
    final res = await _http.post<Map<String, dynamic>>('/products', body: item.toJson());
    return Product.fromJson(res);
  }

  @override
  Future<Product> update(String id, Product item) async {
    final res = await _http.patch<Map<String, dynamic>>('/products/$id', body: item.toJson());
    return Product.fromJson(res);
  }

  @override
  Future<bool> delete(String id) async {
    await _http.delete('/products/$id');
    return true;
  }
}
```
