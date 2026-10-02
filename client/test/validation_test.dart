import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shop_client/core/combine_latest.dart';
import 'package:shop_client/core/validation.dart';

void main() {
  group('sanitizeText', () {
    test('cắt khoảng trắng thừa ở hai đầu và ở giữa', () {
      expect(sanitizeText('  iPhone 15   Pro  '), 'iPhone 15 Pro');
    });

    test('loại ký tự điều khiển', () {
      expect(sanitizeText('a\u0000b\u0007c\u007Fd'), 'a b c d');
    });

    test('bỏ thẻ HTML — chốn nhập <script>', () {
      expect(sanitizeText('<script>alert(1)</script>Sản phẩm'), 'alert(1) Sản phẩm');
      expect(sanitizeText('<img src=x onerror=y>'), '');
    });

    test('thẻ HTML biến thành khoảng trắng chứ không dán liền hai từ', () {
      // Nếu cắt thẻ mà không thay bằng khoảng trắng thì "15<b>Pro</b>Max"
      // thành "15ProMax" — dính liền chữ.
      expect(sanitizeText('iPhone<b>15</b>Pro'), 'iPhone 15 Pro');
    });

    test('bỏ HTML entity rồi gộp khoảng trắng do nó để lại', () {
      expect(sanitizeText('Tom &amp; Jerry'), 'Tom Jerry');
    });

    test('giữ xuống dòng khi keepNewlines, gộp dòng trống thừa', () {
      expect(
        sanitizeText('dòng 1\n\n\n\n\ndòng 2', keepNewlines: true),
        'dòng 1\n\ndòng 2',
      );
    });

    test('gộp xuống dòng thành khoảng trắng khi không keepNewlines', () {
      // Tên sản phẩm là trường một dòng — xuống dòng phải bị gộp lại.
      expect(sanitizeText('dòng 1\ndòng 2'), 'dòng 1 dòng 2');
      expect(sanitizeText('dòng 1\r\n\r\ndòng 2'), 'dòng 1 dòng 2');
    });

    test('null thì ra chuỗi rỗng, không ném lỗi', () {
      expect(sanitizeText(null), '');
    });
  });

  group('slugify', () {
    test('giữ chữ tiếng Việt có dấu thay vì băm vụn thành gạch nối', () {
      expect(slugify('Điện thoại'), 'điện-thoại');
    });

    test('bỏ ký tự đặc biệt, gộp gạch nối, cắt gạch hai đầu', () {
      expect(slugify('  Laptop / Máy tính  '), 'laptop-máy-tính');
    });

    test('chuỗi rỗng thì sinh docID dự phòng chứ không rỗng', () {
      expect(slugify('!!!'), isNotEmpty);
    });
  });

  group('productDocIdFromSku', () {
    test('khớp đúng quy tắc cũ để không đổi docID sản phẩm đang có', () {
      expect(productDocIdFromSku('IP15P'), 'ip15p');
      expect(productDocIdFromSku('SSD-500GB'), 'ssd-500gb');
      expect(productDocIdFromSku('A_B.C'), 'a-b-c');
    });

    test('chữ tiếng Việt trong SKU không sinh docID tiếng Việt', () {
      // validateSku chặn SKU có chữ tiếng Việt, nhưng hàm này phải an toàn
      // dù bị gọi với dữ liệu bẩn.
      expect(productDocIdFromSku('SP Điện'), 'sp-i-n');
    });
  });

  group('parseAmount', () {
    test('đọc được cả hai kiểu viết số tiền Việt Nam', () {
      expect(parseAmount('1500000'), 1500000);
      expect(parseAmount('1.500.000'), 1500000);
      expect(parseAmount('1,500,000'), 1500000);
      expect(parseAmount(' 27390000 '), 27390000);
    });

    test('trả null khi không phải số', () {
      expect(parseAmount('abc'), isNull);
      expect(parseAmount(''), isNull);
      expect(parseAmount('12a'), isNull);
    });
  });

  group('validateProductName', () {
    test('chấp nhận tên hợp lệ', () {
      expect(validateProductName('  iPhone 15 Pro Max  '), isNull);
    });

    test('chặn tên rỗng hoặc toàn khoảng trắng', () {
      expect(validateProductName(''), isNotNull);
      expect(validateProductName('    '), isNotNull);
    });

    test('chặn tên vượt trần độ dài', () {
      expect(validateProductName('x' * kMaxNameLength), isNull);
      expect(validateProductName('x' * (kMaxNameLength + 1)), isNotNull);
    });
  });

  group('validateSku', () {
    test('chấp nhận chữ số và . _ -', () {
      expect(validateSku('IP15P'), isNull);
      expect(validateSku('SSD-500GB'), isNull);
      expect(validateSku('A_B.C'), isNull);
    });

    test('chặn rỗng, có khoảng trắng hoặc ký tự lạ', () {
      expect(validateSku(''), isNotNull);
      expect(validateSku('IP 15'), isNotNull);
      expect(validateSku('IP/15'), isNotNull);
      expect(validateSku('SP#1'), isNotNull);
    });

    test('chặn quá trần độ dài', () {
      expect(validateSku('x' * (kMaxSkuLength + 1)), isNotNull);
    });
  });

  group('validatePrice', () {
    test('chấp nhận 0 và số hợp lệ', () {
      expect(validatePrice('0'), isNull);
      expect(validatePrice('1.500.000'), isNull);
    });

    test('chặn giá âm', () {
      expect(validatePrice('-1'), isNotNull);
    });

    test('chặn giá vượt trần', () {
      expect(validatePrice('${kMaxPriceVnd + 1}'), isNotNull);
    });

    test('chặn giá không phải số', () {
      expect(validatePrice('rẻ'), isNotNull);
      expect(validatePrice(''), isNotNull);
    });
  });

  group('validateEmail', () {
    test('chấp nhận dạng email thường', () {
      expect(validateEmail('a@b.co'), isNull);
      expect(validateEmail('customer@demo.com'), isNull);
      expect(validateEmail('ten.05+tag@sub.domain.vn'), isNull);
    });

    test('chặn thiếu @, thiếu tên miền, hoặc có khoảng trắng', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
      expect(validateEmail('khongco dau'), isNotNull);
      expect(validateEmail('a@b'), isNotNull);
      expect(validateEmail('a b@c.com'), isNotNull);
      expect(validateEmail('@b.com'), isNotNull);
    });
  });

  group('normalizePhone', () {
    test('bỏ khoảng trắng và gạch nối', () {
      expect(normalizePhone('0912 345 678'), '0912345678');
      expect(normalizePhone('0912-345-678'), '0912345678');
    });

    test('đổi mã quốc gia về dạng nội địa', () {
      expect(normalizePhone('+84912345678'), '0912345678');
      expect(normalizePhone('84912345678'), '0912345678');
      expect(normalizePhone('+84 912 345 678'), '0912345678');
    });

    test('số đã ở dạng nội địa thì giữ nguyên', () {
      expect(normalizePhone('0912345678'), '0912345678');
    });

    test('trả chuỗi rỗng cho null thay vì ném lỗi', () {
      expect(normalizePhone(null), '');
    });
  });

  group('validatePhone', () {
    test('chấp nhận 10 số bắt đầu bằng 0', () {
      expect(validatePhone('0912345678'), isNull);
      expect(validatePhone('0912 345 678'), isNull);
      expect(validatePhone('+84912345678'), isNull);
    });

    test('chặn rỗng', () {
      expect(validatePhone(''), isNotNull);
      expect(validatePhone(null), isNotNull);
      expect(validatePhone('   '), isNotNull);
    });

    test('chặn sai độ dài', () {
      expect(validatePhone('091234567'), isNotNull); // 9 số
      expect(validatePhone('09123456789'), isNotNull); // 11 số
    });

    test('chặn số không bắt đầu bằng 0', () {
      expect(validatePhone('912345678'), isNotNull);
      expect(validatePhone('1912345678'), isNotNull);
    });
  });

  group('validateStock', () {
    test('để trống thì hợp lệ (mặc định 0)', () {
      expect(validateStock(''), isNull);
      expect(validateStock(null), isNull);
    });

    test('chặn âm và quá trần', () {
      expect(validateStock('-5'), isNotNull);
      expect(validateStock('${kMaxStock + 1}'), isNotNull);
    });
  });

  group('validateCategoryName', () {
    test('chặn rỗng và quá dài', () {
      expect(validateCategoryName(''), isNotNull);
      expect(validateCategoryName('x' * (kMaxCategoryNameLength + 1)), isNotNull);
    });

    test('chấp nhận tên tiếng Việt có dấu', () {
      expect(validateCategoryName('Phụ kiện'), isNull);
    });
  });

  group('validateSpec', () {
    test('dòng trống thì bỏ qua, không phải lỗi', () {
      expect(validateSpec('', ''), isNull);
      expect(validateSpec('   ', '  '), isNull);
    });

    test('chặn tên và giá trị quá dài', () {
      expect(validateSpec('x' * (kMaxSpecKeyLength + 1), 'v'), isNotNull);
      expect(validateSpec('ram', 'x' * (kMaxSpecValueLength + 1)), isNotNull);
    });

    test('chấp nhận cặp hợp lệ', () {
      expect(validateSpec('RAM', '8GB'), isNull);
    });
  });

  group('validateDescription', () {
    test('chặn quá trần, chấp nhận kể cả có HTML vì đã được cắt', () {
      expect(validateDescription('a' * (kMaxDescriptionLength + 1)), isNotNull);
      expect(validateDescription('Mô tả ngắn'), isNull);
    });
  });

  group('combineLatest', () {
    test('chỉ phát khi đã có giá trị của mọi nhánh', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final out = <List<int>>[];

      final sub = combineLatest<int>([a.stream, b.stream]).listen(out.add);
      addTearDown(() async {
        await sub.cancel();
        await a.close();
        await b.close();
      });

      a.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(out, isEmpty, reason: 'một nhánh chưa có dữ liệu thì chưa được phát');

      b.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(out, [[1, 2]]);
    });

    test('một nhánh phát lại thì lấy giá trị mới nhất của nhánh còn lại', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final out = <List<int>>[];

      final sub = combineLatest<int>([a.stream, b.stream]).listen(out.add);
      addTearDown(() async {
        await sub.cancel();
        await a.close();
        await b.close();
      });

      a.add(1);
      b.add(2);
      await Future<void>.delayed(Duration.zero);
      b.add(9);
      await Future<void>.delayed(Duration.zero);

      expect(out, [
        [1, 2],
        [1, 9],
      ]);
    });

    test('lỗi của một nhánh được chuyển tiếp ra ngoài', () async {
      final a = StreamController<int>();
      final out = <List<int>>[];
      final errors = <Object>[];

      final sub =
          combineLatest<int>([a.stream, Stream<int>.error('hỏng')]).listen(out.add, onError: errors.add);
      addTearDown(() async {
        await sub.cancel();
        await a.close();
      });

      await Future<void>.delayed(Duration.zero);
      expect(errors, isNotEmpty);
    });

    test('ném lỗi khi không có nhánh nào', () {
      expect(() => combineLatest<int>([]), throwsArgumentError);
    });
  });
}
