import 'package:test/test.dart';
import 'package:bloom_js_native/bloom_js_native.dart';

enum CounterAction { increment, decrement, reset }

int counterReducer(int state, CounterAction action) {
  return switch (action) {
    CounterAction.increment => state + 1,
    CounterAction.decrement => state - 1,
    CounterAction.reset => 0,
  };
}

void main() {
  group('BloomReducer', () {
    test('initial state matches the given initialState', () {
      final reducer = useReducer(counterReducer, 0);
      expect(reducer.state.value, 0);
    });

    test('dispatch applies the reducer function', () {
      final reducer = useReducer(counterReducer, 0);
      reducer.dispatch(CounterAction.increment);
      expect(reducer.state.value, 1);
    });

    test('multiple dispatches accumulate via the reducer', () {
      final reducer = useReducer(counterReducer, 0);
      reducer.dispatch(CounterAction.increment);
      reducer.dispatch(CounterAction.increment);
      reducer.dispatch(CounterAction.decrement);
      expect(reducer.state.value, 1);
    });

    test('reset action returns to a fixed value', () {
      final reducer = useReducer(counterReducer, 0);
      reducer.dispatch(CounterAction.increment);
      reducer.dispatch(CounterAction.increment);
      reducer.dispatch(CounterAction.reset);
      expect(reducer.state.value, 0);
    });

    test('history records dispatched actions in order', () {
      final reducer = useReducer(counterReducer, 0);
      reducer.dispatch(CounterAction.increment);
      reducer.dispatch(CounterAction.decrement);
      expect(reducer.history, [CounterAction.increment, CounterAction.decrement]);
    });

    test('state signal notifies effects on dispatch', () {
      final reducer = useReducer(counterReducer, 0);
      final seen = <int>[];
      effect(() => seen.add(reducer.state.value));
      reducer.dispatch(CounterAction.increment);
      reducer.dispatch(CounterAction.increment);
      expect(seen, [0, 1, 2]);
    });

    test('works with a record/object-shaped state', () {
      final reducer = useReducer<Map<String, int>, String>(
        (state, action) {
          switch (action) {
            case 'add':
              return {...state, 'count': (state['count'] ?? 0) + 1};
            default:
              return state;
          }
        },
        const {'count': 0},
      );
      reducer.dispatch('add');
      reducer.dispatch('add');
      expect(reducer.state.value['count'], 2);
    });
  });
}
