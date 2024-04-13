// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      firstName: json['firstName'] as String,
    )
      ..lastName = json['lastName'] as String?
      ..phoneNumber = json['phoneNumber'] as String?
      ..email = json['email'] as String?
      ..createdAt = json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String)
      ..updatedAt = json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String)
      ..isStaff = json['isStaff'] as bool
      ..isSuperUser = json['isSuperUser'] as bool;

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'phoneNumber': instance.phoneNumber,
      'email': instance.email,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'isStaff': instance.isStaff,
      'isSuperUser': instance.isSuperUser,
    };

UserInterestAndInteraction _$UserInterestAndInteractionFromJson(
        Map<String, dynamic> json) =>
    UserInterestAndInteraction(
      catagory: Catagory.fromJson(json['catagory'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserInterestAndInteractionToJson(
        UserInterestAndInteraction instance) =>
    <String, dynamic>{
      'catagory': instance.catagory,
      'user': instance.user,
    };

Catagory _$CatagoryFromJson(Map<String, dynamic> json) => Catagory(
      name: json['name'] as String,
    )..desc = json['desc'] as String?;

Map<String, dynamic> _$CatagoryToJson(Catagory instance) => <String, dynamic>{
      'name': instance.name,
      'desc': instance.desc,
    };

Brand _$BrandFromJson(Map<String, dynamic> json) => Brand(
      name: json['name'] as String,
    )
      ..catagory = json['catagory'] == null
          ? null
          : Catagory.fromJson(json['catagory'] as Map<String, dynamic>)
      ..desc = json['desc'] as String?;

Map<String, dynamic> _$BrandToJson(Brand instance) => <String, dynamic>{
      'name': instance.name,
      'catagory': instance.catagory,
      'desc': instance.desc,
    };

Address _$AddressFromJson(Map<String, dynamic> json) => Address()
  ..lat = (json['lat'] as num?)?.toDouble()
  ..lng = (json['lng'] as num?)?.toDouble()
  ..plusCode = json['plusCode'] as String?
  ..sublocality = json['sublocality'] as String?
  ..locality = json['locality'] as String?
  ..admin1 = json['admin1'] as String?
  ..admin2 = json['admin2'] as String?
  ..country = json['country'] as String?;

Map<String, dynamic> _$AddressToJson(Address instance) => <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'plusCode': instance.plusCode,
      'sublocality': instance.sublocality,
      'locality': instance.locality,
      'admin1': instance.admin1,
      'admin2': instance.admin2,
      'country': instance.country,
    };

Shop _$ShopFromJson(Map<String, dynamic> json) => Shop(
      name: json['name'] as String,
      owner: User.fromJson(json['owner'] as Map<String, dynamic>),
      address: Address.fromJson(json['address'] as Map<String, dynamic>),
    )
      ..catagory = json['catagory'] == null
          ? null
          : Catagory.fromJson(json['catagory'] as Map<String, dynamic>)
      ..logo = json['logo'] as String?
      ..bgImage = json['bgImage'] as String?
      ..createdAt = DateTime.parse(json['createdAt'] as String);

Map<String, dynamic> _$ShopToJson(Shop instance) => <String, dynamic>{
      'name': instance.name,
      'owner': instance.owner,
      'address': instance.address,
      'catagory': instance.catagory,
      'logo': instance.logo,
      'bgImage': instance.bgImage,
      'createdAt': instance.createdAt.toIso8601String(),
    };

ShopAcitiviy _$ShopAcitiviyFromJson(Map<String, dynamic> json) => ShopAcitiviy(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    )..action = json['action'] as String?;

Map<String, dynamic> _$ShopAcitiviyToJson(ShopAcitiviy instance) =>
    <String, dynamic>{
      'user': instance.user,
      'action': instance.action,
    };

ShopReview _$ShopReviewFromJson(Map<String, dynamic> json) => ShopReview(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      shop: Shop.fromJson(json['shop'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ShopReviewToJson(ShopReview instance) =>
    <String, dynamic>{
      'user': instance.user,
      'shop': instance.shop,
    };

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      name: json['name'] as String,
      buyingPrice: (json['buyingPrice'] as num).toDouble(),
      sellingPrice: (json['sellingPrice'] as num).toDouble(),
    )
      ..quantity = json['quantity'] as int
      ..desc = json['desc'] as String?;

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'name': instance.name,
      'buyingPrice': instance.buyingPrice,
      'sellingPrice': instance.sellingPrice,
      'quantity': instance.quantity,
      'desc': instance.desc,
    };

Like _$LikeFromJson(Map<String, dynamic> json) => Like(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LikeToJson(Like instance) => <String, dynamic>{
      'product': instance.product,
    };

Follow _$FollowFromJson(Map<String, dynamic> json) => Follow(
      shop: Shop.fromJson(json['shop'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FollowToJson(Follow instance) => <String, dynamic>{
      'shop': instance.shop,
      'user': instance.user,
    };

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
      shop: Shop.fromJson(json['shop'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    )
      ..status = json['status'] as String?
      ..type = json['type'] as String?
      ..msg = json['msg'] as String?;

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
      'status': instance.status,
      'type': instance.type,
      'msg': instance.msg,
      'shop': instance.shop,
      'user': instance.user,
    };

Items _$ItemsFromJson(Map<String, dynamic> json) => Items(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
    )
      ..quantity = json['quantity'] as int
      ..order = json['order'] == null
          ? null
          : Order.fromJson(json['order'] as Map<String, dynamic>)
      ..createdAt = json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String);

Map<String, dynamic> _$ItemsToJson(Items instance) => <String, dynamic>{
      'product': instance.product,
      'quantity': instance.quantity,
      'order': instance.order,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

Notification _$NotificationFromJson(Map<String, dynamic> json) => Notification(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      type: json['type'] as String,
    );

Map<String, dynamic> _$NotificationToJson(Notification instance) =>
    <String, dynamic>{
      'user': instance.user,
      'timestamp': instance.timestamp.toIso8601String(),
      'title': instance.title,
      'content': instance.content,
      'type': instance.type,
    };

GiftCard _$GiftCardFromJson(Map<String, dynamic> json) => GiftCard(
      coupon_id: json['coupon_id'] as String,
      owner: User.fromJson(json['owner'] as Map<String, dynamic>),
    )
      ..createdBy = json['createdBy'] == null
          ? null
          : User.fromJson(json['createdBy'] as Map<String, dynamic>)
      ..product = json['product'] == null
          ? null
          : Product.fromJson(json['product'] as Map<String, dynamic>)
      ..shop = json['shop'] == null
          ? null
          : Shop.fromJson(json['shop'] as Map<String, dynamic>)
      ..redeemed = json['redeemed'] as bool?
      ..expireDate = json['expireDate'] == null
          ? null
          : DateTime.parse(json['expireDate'] as String);

Map<String, dynamic> _$GiftCardToJson(GiftCard instance) => <String, dynamic>{
      'coupon_id': instance.coupon_id,
      'owner': instance.owner,
      'createdBy': instance.createdBy,
      'product': instance.product,
      'shop': instance.shop,
      'redeemed': instance.redeemed,
      'expireDate': instance.expireDate?.toIso8601String(),
    };

Blocked _$BlockedFromJson(Map<String, dynamic> json) => Blocked()
  ..user = json['user'] == null
      ? null
      : User.fromJson(json['user'] as Map<String, dynamic>)
  ..shop = json['shop'] == null
      ? null
      : Shop.fromJson(json['shop'] as Map<String, dynamic>)
  ..product = json['product'] == null
      ? null
      : Product.fromJson(json['product'] as Map<String, dynamic>)
  ..endDate = json['endDate'] == null
      ? null
      : DateTime.parse(json['endDate'] as String);

Map<String, dynamic> _$BlockedToJson(Blocked instance) => <String, dynamic>{
      'user': instance.user,
      'shop': instance.shop,
      'product': instance.product,
      'endDate': instance.endDate?.toIso8601String(),
    };

Policy _$PolicyFromJson(Map<String, dynamic> json) => Policy()
  ..number = json['number'] as int?
  ..detail = json['detail'] as String?
  ..createdAt = DateTime.parse(json['createdAt'] as String);

Map<String, dynamic> _$PolicyToJson(Policy instance) => <String, dynamic>{
      'number': instance.number,
      'detail': instance.detail,
      'createdAt': instance.createdAt.toIso8601String(),
    };

Report _$ReportFromJson(Map<String, dynamic> json) => Report(
      shop: Shop.fromJson(json['shop'] as Map<String, dynamic>),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    )
      ..policy = json['policy'] == null
          ? null
          : Policy.fromJson(json['policy'] as Map<String, dynamic>)
      ..violator = json['violator'] == null
          ? null
          : User.fromJson(json['violator'] as Map<String, dynamic>)
      ..product = json['product'] == null
          ? null
          : Product.fromJson(json['product'] as Map<String, dynamic>)
      ..desc = json['desc'] as String?;

Map<String, dynamic> _$ReportToJson(Report instance) => <String, dynamic>{
      'policy': instance.policy,
      'shop': instance.shop,
      'user': instance.user,
      'violator': instance.violator,
      'product': instance.product,
      'desc': instance.desc,
    };

// **************************************************************************
// Generator: ModelFromJsonAnnotation
// **************************************************************************

extension UserExt on User {
  static String table = 'user';
  static List<String> get columns => [
        '_userId',
        'firstName',
        'lastName',
        'phoneNumber',
        'email',
        'createdAt',
        'updatedAt',
        'isStaff',
        'isSuperUser',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<User> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$UserFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$UserToJson(this);
  static Future<Iterable<User>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$UserFromJson(element.toColumnMap()));
  }

  static Future<Iterable<User>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension UserInterestAndInteractionExt on UserInterestAndInteraction {
  static String table = 'userinterestandinteraction';
  static List<String> get columns =>
      ['_userinterestandinteractionId', 'catagory', 'user', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<UserInterestAndInteraction> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$UserInterestAndInteractionFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$UserInterestAndInteractionToJson(this);
  static Future<Iterable<UserInterestAndInteraction>> filter(
      [Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) =>
        _$UserInterestAndInteractionFromJson(element.toColumnMap()));
  }

  static Future<Iterable<UserInterestAndInteraction>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension CatagoryExt on Catagory {
  static String table = 'catagory';
  static List<String> get columns => ['_catagoryId', 'name', 'desc', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Catagory> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$CatagoryFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$CatagoryToJson(this);
  static Future<Iterable<Catagory>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$CatagoryFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Catagory>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension BrandExt on Brand {
  static String table = 'brand';
  static List<String> get columns =>
      ['_brandId', 'name', 'catagory', 'desc', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Brand> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$BrandFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$BrandToJson(this);
  static Future<Iterable<Brand>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$BrandFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Brand>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension AddressExt on Address {
  static String table = 'address';
  static List<String> get columns => [
        '_addressId',
        'lat',
        'lng',
        'plusCode',
        'sublocality',
        'locality',
        'admin1',
        'admin2',
        'country',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Address> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$AddressFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$AddressToJson(this);
  static Future<Iterable<Address>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$AddressFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Address>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension ShopExt on Shop {
  static String table = 'shop';
  static List<String> get columns => [
        '_shopId',
        'name',
        'owner',
        'address',
        'catagory',
        'logo',
        'bgImage',
        'createdAt',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Shop> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$ShopFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$ShopToJson(this);
  static Future<Iterable<Shop>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$ShopFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Shop>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension ShopAcitiviyExt on ShopAcitiviy {
  static String table = 'shopacitiviy';
  static List<String> get columns =>
      ['_shopacitiviyId', 'user', 'action', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<ShopAcitiviy> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$ShopAcitiviyFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$ShopAcitiviyToJson(this);
  static Future<Iterable<ShopAcitiviy>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result
        .map((element) => _$ShopAcitiviyFromJson(element.toColumnMap()));
  }

  static Future<Iterable<ShopAcitiviy>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension ShopReviewExt on ShopReview {
  static String table = 'shopreview';
  static List<String> get columns => ['_shopreviewId', 'user', 'shop', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<ShopReview> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$ShopReviewFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$ShopReviewToJson(this);
  static Future<Iterable<ShopReview>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$ShopReviewFromJson(element.toColumnMap()));
  }

  static Future<Iterable<ShopReview>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension ProductExt on Product {
  static String table = 'product';
  static List<String> get columns => [
        '_productId',
        'name',
        'buyingPrice',
        'sellingPrice',
        'quantity',
        'desc',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Product> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$ProductFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$ProductToJson(this);
  static Future<Iterable<Product>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$ProductFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Product>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension LikeExt on Like {
  static String table = 'like';
  static List<String> get columns => ['_likeId', 'product', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Like> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$LikeFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$LikeToJson(this);
  static Future<Iterable<Like>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$LikeFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Like>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension FollowExt on Follow {
  static String table = 'follow';
  static List<String> get columns => ['_followId', 'shop', 'user', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Follow> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$FollowFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$FollowToJson(this);
  static Future<Iterable<Follow>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$FollowFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Follow>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension OrderExt on Order {
  static String table = 'order';
  static List<String> get columns =>
      ['_orderId', 'status', 'type', 'msg', 'shop', 'user', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Order> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$OrderFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$OrderToJson(this);
  static Future<Iterable<Order>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$OrderFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Order>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension ItemsExt on Items {
  static String table = 'items';
  static List<String> get columns =>
      ['_itemsId', 'product', 'quantity', 'order', 'createdAt', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Items> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$ItemsFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$ItemsToJson(this);
  static Future<Iterable<Items>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$ItemsFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Items>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension NotificationExt on Notification {
  static String table = 'notification';
  static List<String> get columns => [
        '_notificationId',
        'user',
        'timestamp',
        'title',
        'content',
        'type',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Notification> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$NotificationFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$NotificationToJson(this);
  static Future<Iterable<Notification>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result
        .map((element) => _$NotificationFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Notification>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension GiftCardExt on GiftCard {
  static String table = 'giftcard';
  static List<String> get columns => [
        '_giftcardId',
        'coupon_id',
        'owner',
        'createdBy',
        'product',
        'shop',
        'redeemed',
        'expireDate',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<GiftCard> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$GiftCardFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$GiftCardToJson(this);
  static Future<Iterable<GiftCard>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$GiftCardFromJson(element.toColumnMap()));
  }

  static Future<Iterable<GiftCard>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension BlockedExt on Blocked {
  static String table = 'blocked';
  static List<String> get columns =>
      ['_blockedId', 'user', 'shop', 'product', 'endDate', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Blocked> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$BlockedFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$BlockedToJson(this);
  static Future<Iterable<Blocked>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$BlockedFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Blocked>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension PolicyExt on Policy {
  static String table = 'policy';
  static List<String> get columns =>
      ['_policyId', 'number', 'detail', 'createdAt', 'table'];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Policy> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$PolicyFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$PolicyToJson(this);
  static Future<Iterable<Policy>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$PolicyFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Policy>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}

extension ReportExt on Report {
  static String table = 'report';
  static List<String> get columns => [
        '_reportId',
        'policy',
        'shop',
        'user',
        'violator',
        'product',
        'desc',
        'table'
      ];
  static Future<int> count([Operation? op]) async {
    final conn = await Database().connection;
    final query =
        Query.select(table: table, columns: columns, operation: op).count();
    final result = await conn.execute(query);
    return result.first.toColumnMap()['count'] as int;
  }

  Future<Report> update(Map<String, dynamic> json) async {
    if (id == null || json.isEmpty) return this;
    final conn = await Database().connection;
    final query = Query.update(
      table: table,
      columns: json,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return _$ReportFromJson(result.first.toColumnMap());
  }

  Map<String, dynamic> toJson() => _$ReportToJson(this);
  static Future<Iterable<Report>> filter([Operation? op]) async {
    final conn = await Database().connection;

    final query = Query.select(table: table, columns: columns, operation: op);

    final result = await conn.execute(query.toString());

    return result.map((element) => _$ReportFromJson(element.toColumnMap()));
  }

  static Future<Iterable<Report>> all() async => filter();
  Future<int> delete() async {
    final conn = await Database().connection;
    if (id == null) return -1;

    final query = Query.delete(
      table: table,
      operation: Operation('id', Operator.eq, id),
    );
    final result = await conn.execute(query.toString());

    return result.first.isEmpty ? -1 : id!;
  }
}
