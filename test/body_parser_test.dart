import 'dart:convert';

import 'package:gisila/gisila.dart';
import 'package:test/test.dart';

void main() {
  group('readBody dispatcher', () {
    test('decodes application/json into a Map', () async {
      final request = Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'application/json'},
        body: '{"name":"alice","age":30}',
      );
      final body = await readBody(request);
      expect(body, isA<Map<String, dynamic>>());
      expect((body as Map)['name'], 'alice');
      expect(body['age'], 30);
    });

    test('decodes application/x-www-form-urlencoded into FormData', () async {
      final request = Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'name=alice&age=30',
      );
      final body = await readBody(request);
      expect(body, isA<FormData>());
      final form = body! as FormData;
      expect(form.fields['name'], 'alice');
      expect(form.fields['age'], '30');
      expect(form['name'], 'alice', reason: 'MapMixin lookup works');
    });

    test('decodes multipart/form-data into FormData with files', () async {
      const boundary = '----gisila_test_boundary';
      final body = StringBuffer()
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; name="note"\r\n\r\n')
        ..write('hello world\r\n')
        ..write('--$boundary\r\n')
        ..write('Content-Disposition: form-data; '
            'name="file"; filename="hi.txt"\r\n')
        ..write('Content-Type: text/plain\r\n\r\n')
        ..write('abc\r\n')
        ..write('--$boundary--\r\n');

      final request = Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'multipart/form-data; boundary=$boundary'},
        body: body.toString(),
      );
      final result = await readBody(request);
      expect(result, isA<FormData>());
      final form = result! as FormData;
      expect(form.fields['note'], 'hello world');
      expect(form.files.keys, contains('file'));
      final f = form.files['file']!;
      expect(f.name, 'hi.txt');
      expect(f.contentType.mimeType, 'text/plain');
      expect(utf8.decode(await f.readAsBytes()), 'abc');
    });

    test('rejects unsupported content types with BadRequestException',
        () async {
      final request = Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'text/plain'},
        body: 'hi',
      );
      expect(
        () => readBody(request),
        throwsA(isA<HttpException>().having(
            (e) => e.statusCode, 'status', 400)),
      );
    });

    test('returns null when body is absent and required: false', () async {
      final request = Request('GET', Uri.parse('http://x/'));
      final body = await readBody(request, required: false);
      expect(body, isNull);
    });

    test('throws when body is required but content-type is missing',
        () async {
      final request = Request('POST', Uri.parse('http://x/'));
      expect(
        () => readBody(request),
        throwsA(isA<BadRequestException>()),
      );
    });
  });

  group('readFormBody', () {
    test('throws on JSON content type', () async {
      final request = Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'application/json'},
        body: '{}',
      );
      expect(() => readFormBody(request),
          throwsA(isA<BadRequestException>()));
    });

    test('returns FormData for urlencoded', () async {
      final request = Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: 'a=1&b=2',
      );
      final form = await readFormBody(request);
      expect(form, isA<FormData>());
      expect(form!.fields, {'a': '1', 'b': '2'});
    });
  });

  group('allowedContentTypesMiddleware', () {
    test('lets GET requests through unconditionally', () async {
      final handler = allowedContentTypesMiddleware()(
          (_) async => Response.ok('ok'));
      final res = await handler(Request('GET', Uri.parse('http://x/')));
      expect(res.statusCode, 200);
    });

    test('returns 415 for unsupported POST content type', () async {
      final handler = allowedContentTypesMiddleware()(
          (_) async => Response.ok('ok'));
      final res = await handler(Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'text/plain'},
        body: 'hi',
      ));
      expect(res.statusCode, 415);
      final body = jsonDecode(await res.readAsString()) as Map;
      expect((body['error'] as Map)['code'], 'unsupported_media_type');
    });

    test('accepts allowed POST content type', () async {
      final handler = allowedContentTypesMiddleware()(
          (_) async => Response.ok('ok'));
      final res = await handler(Request(
        'POST',
        Uri.parse('http://x/'),
        headers: {'content-type': 'multipart/form-data; boundary=x'},
        body: '',
      ));
      expect(res.statusCode, 200);
    });
  });
}
