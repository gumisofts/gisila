/// A controller exercising guards, binding, timeouts and rate limits, for
/// `pipeline_integration_test.dart`. Its generated part is checked in;
/// `generated_golden_test.dart` fails when the generator's output for it
/// changes, so update the part when that change is intended.
library;

import 'package:gisila/gisila.dart';

part 'guarded_controller.g.dart';

class NoteForm extends Form {
  final title = StringField(name: 'title', required: true, maxLength: 20);
  final stars = IntField(name: 'stars', min: 1, max: 5);

  @override
  List<FormField<Object?>> collectFields() => [title, stars];
}

@Controller('/x')
@RequireAuth()
class GuardedController {
  @Get('/')
  @Public()
  Future<Map<String, Object?>> index() async => {'index': true};

  @Get('/public')
  @Public()
  Future<Map<String, Object?>> open() async => {'ok': true};

  @Get('/me')
  Future<Map<String, Object?>> me(RequestContext ctx) async =>
      {'id': ctx.principal!.id};

  @Post('/notes')
  @Permissions({'write'})
  Future<Map<String, Object?>> create(NoteForm form) async =>
      {'title': form.title.value, 'stars': form.stars.value};

  @Get('/admin')
  @Roles({'admin'})
  Future<Map<String, Object?>> admin() async => {'admin': true};

  @Get('/items/{id}')
  @Public()
  Future<Map<String, Object?>> item(int id, {int? page}) async =>
      {'id': id, 'page': page};

  @Get('/slow', config: RouteConfig(timeout: Duration(milliseconds: 50)))
  @Public()
  Future<Map<String, Object?>> slow() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return {};
  }

  @Get('/limited',
      config: RouteConfig(rateLimit: RateLimitConfig(requestsPerMinute: 2)))
  @Public()
  Future<Map<String, Object?>> limited() async => {};

  @Get('/boom')
  @Public()
  Future<Map<String, Object?>> boom() async =>
      throw StateError('secret detail');
}
