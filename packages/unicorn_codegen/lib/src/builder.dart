import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'generators/dsl_generator.dart';

Builder dslBuilder(BuilderOptions options) => LibraryBuilder(DslGenerator());
