import 'package:d_orm/database/extensions.dart';
import 'package:d_orm/database/database.dart';
import 'package:postgres/postgres.dart';
import 'package:d_orm/database/models.dart';
part 'schema.db.g.dart';
part 'schema.query.g.dart';

class User {
  User({
    required String firstName,
    this.id,
    String? lastName,
    String? phoneNumber,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isStaff,
    bool? isSuperUser,
  }) {
    _firstName = firstName;
    _lastName = lastName;
    _phoneNumber = phoneNumber;
    _email = email;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _isStaff = isStaff;
    _isSuperUser = isSuperUser;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "User",
        columns: _updatedFields,
        operation: Operation("userId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return UserDb.delete(this);
  }

  late String _firstName;
  String get firstName => _firstName;
  set firstName(String m) {
    _updatedFields['firstName'] = m;
    _firstName = m;
  }

  String? _lastName;
  String? get lastName => _lastName;
  set lastName(String? m) {
    _updatedFields['lastName'] = m;
    _lastName = m;
  }

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;
  set phoneNumber(String? m) {
    _updatedFields['phoneNumber'] = m;
    _phoneNumber = m;
  }

  String? _email;
  String? get email => _email;
  set email(String? m) {
    _updatedFields['email'] = m;
    _email = m;
  }

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? m) {
    _updatedFields['createdAt'] = m;
    _createdAt = m;
  }

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  set updatedAt(DateTime? m) {
    _updatedFields['updatedAt'] = m;
    _updatedAt = m;
  }

  bool? _isStaff;
  bool? get isStaff => _isStaff;
  set isStaff(bool? m) {
    _updatedFields['isStaff'] = m;
    _isStaff = m;
  }

  bool? _isSuperUser;
  bool? get isSuperUser => _isSuperUser;
  set isSuperUser(bool? m) {
    _updatedFields['isSuperUser'] = m;
    _isSuperUser = m;
  }
}

class UserInterestAndInteraction {
  UserInterestAndInteraction({
    required int catagoryId,
    required int userId,
    this.id,
  }) {
    _catagoryId = catagoryId;
    _userId = userId;
  }
  late int _catagoryId;
  int get catagoryId => _catagoryId;
  set catagoryId(int id) {
    _updatedFields["catagory"] = id;
    _catagoryId = id;
  }

  ModelHolder<Catagory>? _getcatagory;
  Future<Catagory?> get catagory {
    _getcatagory ??= ModelHolder<Catagory>(
        getModelInstance: () =>
            CatagoryDb.get(where: (t) => t.id.equals(catagoryId)));
    return _getcatagory!.instance;
  }

  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "UserInterestAndInteraction",
        columns: _updatedFields,
        operation: Operation("userinterestandinteractionId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return UserInterestAndInteractionDb.delete(this);
  }
}

class Catagory {
  Catagory({
    required String name,
    this.id,
    String? desc,
  }) {
    _name = name;
    _desc = desc;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Catagory",
        columns: _updatedFields,
        operation: Operation("catagoryId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return CatagoryDb.delete(this);
  }

  late String _name;
  String get name => _name;
  set name(String m) {
    _updatedFields['name'] = m;
    _name = m;
  }

  String? _desc;
  String? get desc => _desc;
  set desc(String? m) {
    _updatedFields['desc'] = m;
    _desc = m;
  }
}

class Brand {
  Brand({
    required String name,
    int? catagoryId,
    this.id,
    String? desc,
  }) {
    _name = name;
    _desc = desc;
    _catagoryId = catagoryId;
  }
  int? _catagoryId;
  int? get catagoryId => _catagoryId;
  set catagoryId(int? id) {
    _updatedFields["catagory"] = id;
    _catagoryId = id;
  }

  ModelHolder<Catagory>? _getcatagory;
  Future<Catagory?> get catagory {
    _getcatagory ??= ModelHolder<Catagory>(
        getModelInstance: () =>
            CatagoryDb.get(where: (t) => t.id.equals(catagoryId!)));
    return _getcatagory!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Brand",
        columns: _updatedFields,
        operation: Operation("brandId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return BrandDb.delete(this);
  }

  late String _name;
  String get name => _name;
  set name(String m) {
    _updatedFields['name'] = m;
    _name = m;
  }

  String? _desc;
  String? get desc => _desc;
  set desc(String? m) {
    _updatedFields['desc'] = m;
    _desc = m;
  }
}

class Address {
  Address({
    this.id,
    double? lat,
    double? lng,
    String? plusCode,
    String? sublocality,
    String? locality,
    String? admin1,
    String? admin2,
    String? country,
  }) {
    _lat = lat;
    _lng = lng;
    _plusCode = plusCode;
    _sublocality = sublocality;
    _locality = locality;
    _admin1 = admin1;
    _admin2 = admin2;
    _country = country;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Address",
        columns: _updatedFields,
        operation: Operation("addressId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return AddressDb.delete(this);
  }

  double? _lat;
  double? get lat => _lat;
  set lat(double? m) {
    _updatedFields['lat'] = m;
    _lat = m;
  }

  double? _lng;
  double? get lng => _lng;
  set lng(double? m) {
    _updatedFields['lng'] = m;
    _lng = m;
  }

  String? _plusCode;
  String? get plusCode => _plusCode;
  set plusCode(String? m) {
    _updatedFields['plusCode'] = m;
    _plusCode = m;
  }

  String? _sublocality;
  String? get sublocality => _sublocality;
  set sublocality(String? m) {
    _updatedFields['sublocality'] = m;
    _sublocality = m;
  }

  String? _locality;
  String? get locality => _locality;
  set locality(String? m) {
    _updatedFields['locality'] = m;
    _locality = m;
  }

  String? _admin1;
  String? get admin1 => _admin1;
  set admin1(String? m) {
    _updatedFields['admin1'] = m;
    _admin1 = m;
  }

  String? _admin2;
  String? get admin2 => _admin2;
  set admin2(String? m) {
    _updatedFields['admin2'] = m;
    _admin2 = m;
  }

  String? _country;
  String? get country => _country;
  set country(String? m) {
    _updatedFields['country'] = m;
    _country = m;
  }
}

class Shop {
  Shop({
    required String name,
    required int ownerId,
    required int addressId,
    int? catagoryId,
    this.id,
    String? logo,
    String? bgImage,
    DateTime? createdAt,
  }) {
    _name = name;
    _logo = logo;
    _bgImage = bgImage;
    _createdAt = createdAt;
    _ownerId = ownerId;
    _addressId = addressId;
    _catagoryId = catagoryId;
  }
  late int _ownerId;
  int get ownerId => _ownerId;
  set ownerId(int id) {
    _updatedFields["owner"] = id;
    _ownerId = id;
  }

  ModelHolder<User>? _getowner;
  Future<User?> get owner {
    _getowner ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(ownerId)));
    return _getowner!.instance;
  }

  late int _addressId;
  int get addressId => _addressId;
  set addressId(int id) {
    _updatedFields["address"] = id;
    _addressId = id;
  }

  ModelHolder<Address>? _getaddress;
  Future<Address?> get address {
    _getaddress ??= ModelHolder<Address>(
        getModelInstance: () =>
            AddressDb.get(where: (t) => t.id.equals(addressId)));
    return _getaddress!.instance;
  }

  int? _catagoryId;
  int? get catagoryId => _catagoryId;
  set catagoryId(int? id) {
    _updatedFields["catagory"] = id;
    _catagoryId = id;
  }

  ModelHolder<Catagory>? _getcatagory;
  Future<Catagory?> get catagory {
    _getcatagory ??= ModelHolder<Catagory>(
        getModelInstance: () =>
            CatagoryDb.get(where: (t) => t.id.equals(catagoryId!)));
    return _getcatagory!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Shop",
        columns: _updatedFields,
        operation: Operation("shopId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return ShopDb.delete(this);
  }

  late String _name;
  String get name => _name;
  set name(String m) {
    _updatedFields['name'] = m;
    _name = m;
  }

  String? _logo;
  String? get logo => _logo;
  set logo(String? m) {
    _updatedFields['logo'] = m;
    _logo = m;
  }

  String? _bgImage;
  String? get bgImage => _bgImage;
  set bgImage(String? m) {
    _updatedFields['bgImage'] = m;
    _bgImage = m;
  }

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? m) {
    _updatedFields['createdAt'] = m;
    _createdAt = m;
  }
}

class ShopAcitiviy {
  ShopAcitiviy({
    required int userId,
    this.id,
    String? action,
  }) {
    _action = action;
    _userId = userId;
  }
  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "ShopAcitiviy",
        columns: _updatedFields,
        operation: Operation("shopacitiviyId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return ShopAcitiviyDb.delete(this);
  }

  String? _action;
  String? get action => _action;
  set action(String? m) {
    _updatedFields['action'] = m;
    _action = m;
  }
}

class ShopReview {
  ShopReview({
    required int userId,
    required int shopId,
    this.id,
  }) {
    _userId = userId;
    _shopId = shopId;
  }
  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  late int _shopId;
  int get shopId => _shopId;
  set shopId(int id) {
    _updatedFields["shop"] = id;
    _shopId = id;
  }

  ModelHolder<Shop>? _getshop;
  Future<Shop?> get shop {
    _getshop ??= ModelHolder<Shop>(
        getModelInstance: () => ShopDb.get(where: (t) => t.id.equals(shopId)));
    return _getshop!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "ShopReview",
        columns: _updatedFields,
        operation: Operation("shopreviewId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return ShopReviewDb.delete(this);
  }
}

class Product {
  Product({
    required String name,
    required double buyingPrice,
    required double sellingPrice,
    required int quantity,
    this.id,
    String? desc,
  }) {
    _name = name;
    _buyingPrice = buyingPrice;
    _sellingPrice = sellingPrice;
    _quantity = quantity;
    _desc = desc;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Product",
        columns: _updatedFields,
        operation: Operation("productId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return ProductDb.delete(this);
  }

  late String _name;
  String get name => _name;
  set name(String m) {
    _updatedFields['name'] = m;
    _name = m;
  }

  late double _buyingPrice;
  double get buyingPrice => _buyingPrice;
  set buyingPrice(double m) {
    _updatedFields['buyingPrice'] = m;
    _buyingPrice = m;
  }

  late double _sellingPrice;
  double get sellingPrice => _sellingPrice;
  set sellingPrice(double m) {
    _updatedFields['sellingPrice'] = m;
    _sellingPrice = m;
  }

  late int _quantity;
  int get quantity => _quantity;
  set quantity(int m) {
    _updatedFields['quantity'] = m;
    _quantity = m;
  }

  String? _desc;
  String? get desc => _desc;
  set desc(String? m) {
    _updatedFields['desc'] = m;
    _desc = m;
  }
}

class Like {
  Like({
    required int productId,
    this.id,
  }) {
    _productId = productId;
  }
  late int _productId;
  int get productId => _productId;
  set productId(int id) {
    _updatedFields["product"] = id;
    _productId = id;
  }

  ModelHolder<Product>? _getproduct;
  Future<Product?> get product {
    _getproduct ??= ModelHolder<Product>(
        getModelInstance: () =>
            ProductDb.get(where: (t) => t.id.equals(productId)));
    return _getproduct!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Like",
        columns: _updatedFields,
        operation: Operation("likeId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return LikeDb.delete(this);
  }
}

class Follow {
  Follow({
    required int shopId,
    required int userId,
    this.id,
  }) {
    _shopId = shopId;
    _userId = userId;
  }
  late int _shopId;
  int get shopId => _shopId;
  set shopId(int id) {
    _updatedFields["shop"] = id;
    _shopId = id;
  }

  ModelHolder<Shop>? _getshop;
  Future<Shop?> get shop {
    _getshop ??= ModelHolder<Shop>(
        getModelInstance: () => ShopDb.get(where: (t) => t.id.equals(shopId)));
    return _getshop!.instance;
  }

  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Follow",
        columns: _updatedFields,
        operation: Operation("followId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return FollowDb.delete(this);
  }
}

class Order {
  Order({
    required int shopId,
    required int userId,
    this.id,
    String? status,
    String? type,
    String? msg,
  }) {
    _status = status;
    _type = type;
    _msg = msg;
    _shopId = shopId;
    _userId = userId;
  }
  late int _shopId;
  int get shopId => _shopId;
  set shopId(int id) {
    _updatedFields["shop"] = id;
    _shopId = id;
  }

  ModelHolder<Shop>? _getshop;
  Future<Shop?> get shop {
    _getshop ??= ModelHolder<Shop>(
        getModelInstance: () => ShopDb.get(where: (t) => t.id.equals(shopId)));
    return _getshop!.instance;
  }

  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Order",
        columns: _updatedFields,
        operation: Operation("orderId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return OrderDb.delete(this);
  }

  String? _status;
  String? get status => _status;
  set status(String? m) {
    _updatedFields['status'] = m;
    _status = m;
  }

  String? _type;
  String? get type => _type;
  set type(String? m) {
    _updatedFields['type'] = m;
    _type = m;
  }

  String? _msg;
  String? get msg => _msg;
  set msg(String? m) {
    _updatedFields['msg'] = m;
    _msg = m;
  }
}

class Items {
  Items({
    required int quantity,
    required int productId,
    int? orderId,
    this.id,
    DateTime? createdAt,
  }) {
    _quantity = quantity;
    _createdAt = createdAt;
    _productId = productId;
    _orderId = orderId;
  }
  late int _productId;
  int get productId => _productId;
  set productId(int id) {
    _updatedFields["product"] = id;
    _productId = id;
  }

  ModelHolder<Product>? _getproduct;
  Future<Product?> get product {
    _getproduct ??= ModelHolder<Product>(
        getModelInstance: () =>
            ProductDb.get(where: (t) => t.id.equals(productId)));
    return _getproduct!.instance;
  }

  int? _orderId;
  int? get orderId => _orderId;
  set orderId(int? id) {
    _updatedFields["order"] = id;
    _orderId = id;
  }

  ModelHolder<Order>? _getorder;
  Future<Order?> get order {
    _getorder ??= ModelHolder<Order>(
        getModelInstance: () =>
            OrderDb.get(where: (t) => t.id.equals(orderId!)));
    return _getorder!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Items",
        columns: _updatedFields,
        operation: Operation("itemsId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return ItemsDb.delete(this);
  }

  late int _quantity;
  int get quantity => _quantity;
  set quantity(int m) {
    _updatedFields['quantity'] = m;
    _quantity = m;
  }

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? m) {
    _updatedFields['createdAt'] = m;
    _createdAt = m;
  }
}

class Notification {
  Notification({
    required DateTime timestamp,
    required String title,
    required String content,
    required String type,
    required int userId,
    this.id,
  }) {
    _timestamp = timestamp;
    _title = title;
    _content = content;
    _type = type;
    _userId = userId;
  }
  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Notification",
        columns: _updatedFields,
        operation: Operation("notificationId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return NotificationDb.delete(this);
  }

  late DateTime _timestamp;
  DateTime get timestamp => _timestamp;
  set timestamp(DateTime m) {
    _updatedFields['timestamp'] = m;
    _timestamp = m;
  }

  late String _title;
  String get title => _title;
  set title(String m) {
    _updatedFields['title'] = m;
    _title = m;
  }

  late String _content;
  String get content => _content;
  set content(String m) {
    _updatedFields['content'] = m;
    _content = m;
  }

  late String _type;
  String get type => _type;
  set type(String m) {
    _updatedFields['type'] = m;
    _type = m;
  }
}

class GiftCard {
  GiftCard({
    required String coupon_id,
    required int ownerId,
    int? createdById,
    int? productId,
    int? shopId,
    this.id,
    bool? redeemed,
    DateTime? expireDate,
  }) {
    _coupon_id = coupon_id;
    _redeemed = redeemed;
    _expireDate = expireDate;
    _ownerId = ownerId;
    _createdById = createdById;
    _productId = productId;
    _shopId = shopId;
  }
  late int _ownerId;
  int get ownerId => _ownerId;
  set ownerId(int id) {
    _updatedFields["owner"] = id;
    _ownerId = id;
  }

  ModelHolder<User>? _getowner;
  Future<User?> get owner {
    _getowner ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(ownerId)));
    return _getowner!.instance;
  }

  int? _createdById;
  int? get createdById => _createdById;
  set createdById(int? id) {
    _updatedFields["createdBy"] = id;
    _createdById = id;
  }

  ModelHolder<User>? _getcreatedBy;
  Future<User?> get createdBy {
    _getcreatedBy ??= ModelHolder<User>(
        getModelInstance: () =>
            UserDb.get(where: (t) => t.id.equals(createdById!)));
    return _getcreatedBy!.instance;
  }

  int? _productId;
  int? get productId => _productId;
  set productId(int? id) {
    _updatedFields["product"] = id;
    _productId = id;
  }

  ModelHolder<Product>? _getproduct;
  Future<Product?> get product {
    _getproduct ??= ModelHolder<Product>(
        getModelInstance: () =>
            ProductDb.get(where: (t) => t.id.equals(productId!)));
    return _getproduct!.instance;
  }

  int? _shopId;
  int? get shopId => _shopId;
  set shopId(int? id) {
    _updatedFields["shop"] = id;
    _shopId = id;
  }

  ModelHolder<Shop>? _getshop;
  Future<Shop?> get shop {
    _getshop ??= ModelHolder<Shop>(
        getModelInstance: () => ShopDb.get(where: (t) => t.id.equals(shopId!)));
    return _getshop!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "GiftCard",
        columns: _updatedFields,
        operation: Operation("giftcardId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return GiftCardDb.delete(this);
  }

  late String _coupon_id;
  String get coupon_id => _coupon_id;
  set coupon_id(String m) {
    _updatedFields['coupon_id'] = m;
    _coupon_id = m;
  }

  bool? _redeemed;
  bool? get redeemed => _redeemed;
  set redeemed(bool? m) {
    _updatedFields['redeemed'] = m;
    _redeemed = m;
  }

  DateTime? _expireDate;
  DateTime? get expireDate => _expireDate;
  set expireDate(DateTime? m) {
    _updatedFields['expireDate'] = m;
    _expireDate = m;
  }
}

class Blocked {
  Blocked({
    int? userId,
    int? shopId,
    int? productId,
    this.id,
    DateTime? endDate,
  }) {
    _endDate = endDate;
    _userId = userId;
    _shopId = shopId;
    _productId = productId;
  }
  int? _userId;
  int? get userId => _userId;
  set userId(int? id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId!)));
    return _getuser!.instance;
  }

  int? _shopId;
  int? get shopId => _shopId;
  set shopId(int? id) {
    _updatedFields["shop"] = id;
    _shopId = id;
  }

  ModelHolder<Shop>? _getshop;
  Future<Shop?> get shop {
    _getshop ??= ModelHolder<Shop>(
        getModelInstance: () => ShopDb.get(where: (t) => t.id.equals(shopId!)));
    return _getshop!.instance;
  }

  int? _productId;
  int? get productId => _productId;
  set productId(int? id) {
    _updatedFields["product"] = id;
    _productId = id;
  }

  ModelHolder<Product>? _getproduct;
  Future<Product?> get product {
    _getproduct ??= ModelHolder<Product>(
        getModelInstance: () =>
            ProductDb.get(where: (t) => t.id.equals(productId!)));
    return _getproduct!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Blocked",
        columns: _updatedFields,
        operation: Operation("blockedId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return BlockedDb.delete(this);
  }

  DateTime? _endDate;
  DateTime? get endDate => _endDate;
  set endDate(DateTime? m) {
    _updatedFields['endDate'] = m;
    _endDate = m;
  }
}

class Policy {
  Policy({
    required DateTime createdAt,
    this.id,
    int? number,
    String? detail,
  }) {
    _number = number;
    _detail = detail;
    _createdAt = createdAt;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Policy",
        columns: _updatedFields,
        operation: Operation("policyId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return PolicyDb.delete(this);
  }

  int? _number;
  int? get number => _number;
  set number(int? m) {
    _updatedFields['number'] = m;
    _number = m;
  }

  String? _detail;
  String? get detail => _detail;
  set detail(String? m) {
    _updatedFields['detail'] = m;
    _detail = m;
  }

  late DateTime _createdAt;
  DateTime get createdAt => _createdAt;
  set createdAt(DateTime m) {
    _updatedFields['createdAt'] = m;
    _createdAt = m;
  }
}

class Report {
  Report({
    int? policyId,
    required int shopId,
    required int userId,
    int? violatorId,
    int? productId,
    this.id,
    String? desc,
  }) {
    _desc = desc;
    _policyId = policyId;
    _shopId = shopId;
    _userId = userId;
    _violatorId = violatorId;
    _productId = productId;
  }
  int? _policyId;
  int? get policyId => _policyId;
  set policyId(int? id) {
    _updatedFields["policy"] = id;
    _policyId = id;
  }

  ModelHolder<Policy>? _getpolicy;
  Future<Policy?> get policy {
    _getpolicy ??= ModelHolder<Policy>(
        getModelInstance: () =>
            PolicyDb.get(where: (t) => t.id.equals(policyId!)));
    return _getpolicy!.instance;
  }

  late int _shopId;
  int get shopId => _shopId;
  set shopId(int id) {
    _updatedFields["shop"] = id;
    _shopId = id;
  }

  ModelHolder<Shop>? _getshop;
  Future<Shop?> get shop {
    _getshop ??= ModelHolder<Shop>(
        getModelInstance: () => ShopDb.get(where: (t) => t.id.equals(shopId)));
    return _getshop!.instance;
  }

  late int _userId;
  int get userId => _userId;
  set userId(int id) {
    _updatedFields["user"] = id;
    _userId = id;
  }

  ModelHolder<User>? _getuser;
  Future<User?> get user {
    _getuser ??= ModelHolder<User>(
        getModelInstance: () => UserDb.get(where: (t) => t.id.equals(userId)));
    return _getuser!.instance;
  }

  int? _violatorId;
  int? get violatorId => _violatorId;
  set violatorId(int? id) {
    _updatedFields["violator"] = id;
    _violatorId = id;
  }

  ModelHolder<User>? _getviolator;
  Future<User?> get violator {
    _getviolator ??= ModelHolder<User>(
        getModelInstance: () =>
            UserDb.get(where: (t) => t.id.equals(violatorId!)));
    return _getviolator!.instance;
  }

  int? _productId;
  int? get productId => _productId;
  set productId(int? id) {
    _updatedFields["product"] = id;
    _productId = id;
  }

  ModelHolder<Product>? _getproduct;
  Future<Product?> get product {
    _getproduct ??= ModelHolder<Product>(
        getModelInstance: () =>
            ProductDb.get(where: (t) => t.id.equals(productId!)));
    return _getproduct!.instance;
  }

  final _updatedFields = <String, dynamic>{};
  Future<void> save() async {
    if (_updatedFields.isNotEmpty) {
      final query = Query.update(
        table: "Report",
        columns: _updatedFields,
        operation: Operation("reportId", Operator.eq, id),
      );
      final res = await (await Database().pool).execute(query.toString());
    }
  }

  int? id;
  Future<bool> delete() async {
    return ReportDb.delete(this);
  }

  String? _desc;
  String? get desc => _desc;
  set desc(String? m) {
    _updatedFields['desc'] = m;
    _desc = m;
  }
}
