import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;
import 'package:vm_service/vm_service.dart' as vms;
import 'package:path/path.dart' as path;

///
/// gflutter drive --profile --trace-startup -t test_driver/perf.dart -d redmi
///

final homeHeader = find.text('You have pushed the button this many times:');
final newPageFab = find.byValueKey('newPageFab');

/// Returns a [Future] that resolves to true if the widget specified by [finder]
/// is present, false otherwise.
Future<bool> isPresent(SerializableFinder finder, FlutterDriver driver,
    {Duration timeout = const Duration(seconds: 5)}) async {
  try {
    await driver.waitFor(finder, timeout: timeout);
    return true;
  } catch (exception) {
    return false;
  }
}

vms.IsolateRef _selectedIsolate;


Future<vms.IsolateRef> _computeMainIsolate(List<vms.IsolateRef> isolates) async {
  if (isolates.isEmpty) return null;

  // for (vms.IsolateRef ref in isolates) {
  //   if (_selectedIsolate == null) {
  //     final Isolate isolate = await _service.getIsolate(ref.id);
  //     if (isolate.extensionRPCs != null) {
  //       for (String extensionName in isolate.extensionRPCs) {
  //         if (extensions.isFlutterExtension(extensionName)) {
  //           return ref;
  //         }
  //       }
  //     }
  //   }
  // }

  final vms.IsolateRef ref = isolates.firstWhere((vms.IsolateRef ref) {
    // 'foo.dart:main()'
    return ref.name.contains(':main(');
  }, orElse: () => null);

  return ref ?? isolates.first;
}

// Key fields from the VM response JSON.
const nameKey = 'name';
const categoryKey = 'category';
const parentIdKey = 'parent';
const stackFrameIdKey = 'sf';
const resolvedUrlKey = 'resolvedUrl';
const stackFramesKey = 'stackFrames';
const traceEventsKey = 'traceEvents';
const sampleCountKey = 'sampleCount';
const stackDepthKey = 'stackDepth';
const samplePeriodKey = 'samplePeriod';
const timeOriginKey = 'timeOriginMicros';
const timeExtentKey = 'timeExtentMicros';

class _CpuProfileTimelineTree {
  factory _CpuProfileTimelineTree.fromCpuSamples(vms.CpuSamples cpuSamples) {
    final root = _CpuProfileTimelineTree._fromIndex(cpuSamples, kRootIndex);
    _CpuProfileTimelineTree current;
    // TODO(bkonyi): handle truncated?
    for (final sample in cpuSamples.samples) {
      current = root;
      // Build an inclusive trie.
      for (final index in sample.stack.reversed) {
        current = current._getChild(index);
      }
      _timelineTreeExpando[sample] = current;
    }
    return root;
  }

  _CpuProfileTimelineTree._fromIndex(this.samples, this.index);

  static final _timelineTreeExpando = Expando<_CpuProfileTimelineTree>();
  static const kRootIndex = -1;
  static const kNoFrameId = -1;
  final vms.CpuSamples samples;
  final int index;
  int frameId = kNoFrameId;

  String get name => samples.functions[index].function.name;

  String get resolvedUrl => samples.functions[index].resolvedUrl;

  final children = <_CpuProfileTimelineTree>[];

  static _CpuProfileTimelineTree getTreeFromSample(vms.CpuSample sample) =>
      _timelineTreeExpando[sample];

  _CpuProfileTimelineTree _getChild(int index) {
    final length = children.length;
    int i;
    for (i = 0; i < length; ++i) {
      final child = children[i];
      final childIndex = child.index;
      if (childIndex == index) {
        return child;
      }
      if (childIndex > index) {
        break;
      }
    }
    final child = _CpuProfileTimelineTree._fromIndex(samples, index);
    if (i < length) {
      children.insert(i, child);
    } else {
      children.add(child);
    }
    return child;
  }
}

void main([List<String> args = const <String>[]]) {
  group('Flutter App Demo Profile', () {
    FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
      bool present = await isPresent(homeHeader, driver);
      print("setUpAll done : $present");
    });

    tearDownAll(() async {
      if (driver != null) {
        await driver.close();
      }
      print(
          'Timeline summaries for profiled demos have been output to the build/ directory.');
    });

    test(': profile for timeline', () async {
      int index = 0;
      final vms.Timestamp startTimestamp = await driver.serviceClient.getVMTimelineMicros();
      // driver.serviceClient.setVMTimelineFlags(["all"]);
      vms.VM vm  = await driver.serviceClient.getVM();
      vms.IsolateRef isolateRef = await _computeMainIsolate(vm.isolates);

      // Timer.periodic(Duration(seconds: 1), (timer) async {
      //   print("timer");
      //   int timeOriginMicros = startTimestamp.timestamp + index * 1000;
      //   vms.Timeline timeline = await driver.serviceClient.getVMTimeline(
      //       timeOriginMicros: timeOriginMicros, timeExtentMicros: 1000);
      //   print(timeline.toJson());
      //
      //   vms.CpuSamples cpuSamples = await driver.serviceClient.getCpuSamples(isolateRef.id, timeOriginMicros, 1000);
      //   print(cpuSamples.json);
      //
      //   index++;
      // });

      // print("tap");
      // await driver.tap(newPageFab);

      final timeline = await driver.traceAction(
        () async {
          //
          print("tap");
          await driver.tap(newPageFab);
          await Future.delayed(Duration(milliseconds: 200), () {});
          //
        },
        streams: const <TimelineStream>[
          TimelineStream.all,
        ],
      );
      final vms.Timestamp endTimestamp = await driver.serviceClient.getVMTimelineMicros();

      final summary = TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile('profile_for_timeline', includeSummary:true, pretty: true);

      vms.CpuSamples cpuSamples = await driver.serviceClient.getCpuSamples(isolateRef.id, startTimestamp.timestamp, endTimestamp.timestamp - startTimestamp.timestamp);
      // writeCpuProfileToFile("cpu_profile", cpuSamples);

      final isolateId = isolateRef.id;
      const int kRootId = 0;
      int nextId = kRootId;
      final traceObject = <String, dynamic>{
        sampleCountKey: cpuSamples.sampleCount,
        samplePeriodKey: cpuSamples.samplePeriod,
        stackDepthKey: cpuSamples.maxStackDepth,
        timeOriginKey: cpuSamples.timeOriginMicros,
        timeExtentKey: cpuSamples.timeExtentMicros,
        stackFramesKey: {},
        traceEventsKey: [],
      };

      void processStackFrame({_CpuProfileTimelineTree current, _CpuProfileTimelineTree parent,
      }) {
        final id = nextId++;
        current.frameId = id;

        // Skip the root.
        if (id != kRootId) {
          final key = '$isolateId-$id';
          traceObject[stackFramesKey][key] = {
            categoryKey: 'Dart',
            nameKey: current.name,
            resolvedUrlKey: current.resolvedUrl,
            if (parent != null && parent.frameId != 0)
              parentIdKey: '$isolateId-${parent.frameId}',
          };
        }
        for (final child in current.children) {
          processStackFrame(current: child, parent: current);
        }
      }

      final root = _CpuProfileTimelineTree.fromCpuSamples(cpuSamples);
      processStackFrame(current: root, parent: null);

      // Build the trace events.
      for (final sample in cpuSamples.samples) {
        final tree = _CpuProfileTimelineTree.getTreeFromSample(sample);
        // Skip the root.
        if (tree.frameId == kRootId) {
          continue;
        }
        traceObject[traceEventsKey].add({
          'ph': 'P', // kind = sample event
          'name': '', // Blank to keep about:tracing happy
          'pid': cpuSamples.pid,
          'tid': sample.tid,
          'ts': sample.timestamp,
          'cat': 'Dart',
          stackFrameIdKey: '$isolateId-${tree.frameId}',
        });
      }

      writeCpuProfileToFile("cpu_profile", traceObject);

      await Future.delayed(Duration(seconds: 2), () {});

    }, timeout: Timeout.none);
  });
}
const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');
String _encodeJson(Map<String, dynamic> jsonObject, bool pretty) {
  return pretty
      ? _prettyEncoder.convert(jsonObject)
      : json.encode(jsonObject);
}

Future<void> writeCpuProfileToFile(
    String traceName, Map<String, dynamic> json, {
      String destinationDirectory,
      bool pretty = false,
    }) async {
  destinationDirectory ??= testOutputsDirectory;
  await fs.directory(destinationDirectory).create(recursive: true);
  final File file = fs.file(path.join(destinationDirectory, '$traceName.timeline.json'));
  await file.writeAsString(_encodeJson(json, pretty));
}
