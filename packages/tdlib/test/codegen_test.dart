import 'package:test/test.dart';

import '../tool/src/dart_emitter.dart';
import '../tool/src/tl_schema.dart';

const _sample = '''
double ? = Double;
string ? = String;

int32 = Int32;
int53 = Int53;
int64 = Int64;
bytes = Bytes;

boolFalse = Bool;
boolTrue = Bool;

vector {t:Type} # [ t ] = Vector t;


//@description An error @code Error code @message Error message
error code:int32 message:string = Error;

//@class Shape @description A shape

//@description A circle
//@radius Radius
//-in pixels
//@center Center; may be null
shapeCircle radius:double center:point = Shape;

//@description A point @x X @y Y
point x:int53 y:int64 = Point;

---functions---

//@description Draws shapes @shapes Shapes to draw @param_description Description @label Label; pass null to use default
draw shapes:vector<vector<Shape>> description:string label:string = Ok;
''';

void main() {
  final schema = parseTlSchema(_sample);

  test('разбирает типы, функции и документацию', () {
    expect(schema.abstractClasses, {'Shape': 'A shape'});
    expect(
      [for (final o in schema.objects) o.name],
      ['error', 'shapeCircle', 'point'],
    );
    final circle = schema.objects[1];
    expect(circle.resultType, 'Shape');
    expect(circle.params[0].description, 'Radius in pixels');
    expect(circle.params[1].mayBeNull, isTrue);
    expect(circle.params[0].mayBeNull, isFalse);

    final draw = schema.functions.single;
    expect(draw.params[0].type.item!.item!.name, 'Shape');
    expect(draw.params[1].description, 'Description');
    // Строки не бывают null, даже если так сказано в описании.
    expect(draw.params[2].mayBeNull, isFalse);
  });

  test('генерирует sealed-классы и переименовывает конфликты', () {
    final code = emitLibrary(schema, version: '1.0.0', commit: 'abc');
    expect(code, contains('sealed class Shape extends TdObject'));
    expect(code, contains('final class ShapeCircle extends Shape'));
    expect(code, contains('final class TdError extends TdObject'));
    expect(code, contains('final Point? center;'));
    expect(code, contains('final class Draw extends TdFunction<Ok>'));
    expect(code, contains('final List<List<Shape>> shapes;'));
    expect(code, contains("'y': y.toString()"));
  });

  test('имена полей в camelCase', () {
    expect(fieldName('last_read_inbox_message_id'), 'lastReadInboxMessageId');
    expect(className('authorizationStateReady'), 'AuthorizationStateReady');
  });
}
