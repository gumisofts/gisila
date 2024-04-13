import 'package:json_annotation/json_annotation.dart';
import 'package:project_mega/database/database.dart';
import 'package:postgres/postgres.dart';
part 'schema.g.dart';
part 'schema.query.g.dart';

@JsonSerializable()
class User {
  int? _userId;
  int? get id => _userId;
  String firstName;
  String? lastName;
  String? phoneNumber;
  String? email;
  DateTime? createdAt = DateTime.now();
  DateTime? updatedAt = DateTime.now();
  bool isStaff = false;
  bool isSuperUser = false;
  User({required this.firstName});
  static String table = 'user';
  factory User.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return User(firstName: map['firstName'] as String)
      .._userId = map['userId'] as int?
      ..firstName = (map['firstName'] as String)
      ..lastName = (map['lastName'] as String?)
      ..phoneNumber = (map['phoneNumber'] as String?)
      ..email = (map['email'] as String?)
      ..createdAt = (map['createdAt'] as DateTime?)
      ..updatedAt = (map['updatedAt'] as DateTime?)
      ..isStaff = (map['isStaff'] as bool)
      ..isSuperUser = (map['isSuperUser'] as bool);
  }
  static Iterable<User> fromResult(Result result) => result.map(User.fromRow);
  static Future<User?> create(User user) async {
    final json = user.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : User.fromRow(result.first);
  }

  static Future<Iterable<User>> filter(
      {required Operation? Function(UserQuery) where}) async {
    final tt = where(UserQuery());
    final query = Query.select(
      table: UserQuery.table,
      columns: UserQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static User fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class UserInterestAndInteraction {
  int? _userinterestandinteractionId;
  int? get id => _userinterestandinteractionId;
  Catagory catagory;
  User user;
  UserInterestAndInteraction({required this.catagory, required this.user});
  static String table = 'userinterestandinteraction';
  factory UserInterestAndInteraction.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return UserInterestAndInteraction(
        catagory: Catagory.fromRow(row), user: User.fromRow(row))
      .._userinterestandinteractionId =
          map['userinterestandinteractionId'] as int?
      ..catagory = Catagory.fromRow(row)
      ..user = User.fromRow(row);
  }
  static Iterable<UserInterestAndInteraction> fromResult(Result result) =>
      result.map(UserInterestAndInteraction.fromRow);
  static Future<UserInterestAndInteraction?> create(
      UserInterestAndInteraction userinterestandinteraction) async {
    final json = userinterestandinteraction.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty
        ? null
        : UserInterestAndInteraction.fromRow(result.first);
  }

  static Future<Iterable<UserInterestAndInteraction>> filter(
      {required Operation? Function(UserInterestAndInteractionQuery)
          where}) async {
    final tt = where(UserInterestAndInteractionQuery());
    final query = Query.select(
      table: UserInterestAndInteractionQuery.table,
      columns: UserInterestAndInteractionQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static UserInterestAndInteraction fromJson(Map<String, dynamic> json) =>
      _$UserInterestAndInteractionFromJson(json);
  Map<String, dynamic> toJson() => _$UserInterestAndInteractionToJson(this);
}

@JsonSerializable()
class Catagory {
  int? _catagoryId;
  int? get id => _catagoryId;
  String name;
  String? desc;
  Catagory({required this.name});
  static String table = 'catagory';
  factory Catagory.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Catagory(name: map['name'] as String)
      .._catagoryId = map['catagoryId'] as int?
      ..name = (map['name'] as String)
      ..desc = (map['desc'] as String?);
  }
  static Iterable<Catagory> fromResult(Result result) =>
      result.map(Catagory.fromRow);
  static Future<Catagory?> create(Catagory catagory) async {
    final json = catagory.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Catagory.fromRow(result.first);
  }

  static Future<Iterable<Catagory>> filter(
      {required Operation? Function(CatagoryQuery) where}) async {
    final tt = where(CatagoryQuery());
    final query = Query.select(
      table: CatagoryQuery.table,
      columns: CatagoryQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Catagory fromJson(Map<String, dynamic> json) =>
      _$CatagoryFromJson(json);
  Map<String, dynamic> toJson() => _$CatagoryToJson(this);
}

@JsonSerializable()
class Brand {
  int? _brandId;
  int? get id => _brandId;
  String name;
  Catagory? catagory;
  String? desc;
  Brand({required this.name});
  static String table = 'brand';
  factory Brand.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Brand(name: map['name'] as String)
      .._brandId = map['brandId'] as int?
      ..name = (map['name'] as String)
      ..catagory = Catagory?.fromRow(row)
      ..desc = (map['desc'] as String?);
  }
  static Iterable<Brand> fromResult(Result result) => result.map(Brand.fromRow);
  static Future<Brand?> create(Brand brand) async {
    final json = brand.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Brand.fromRow(result.first);
  }

  static Future<Iterable<Brand>> filter(
      {required Operation? Function(BrandQuery) where}) async {
    final tt = where(BrandQuery());
    final query = Query.select(
      table: BrandQuery.table,
      columns: BrandQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Brand fromJson(Map<String, dynamic> json) => _$BrandFromJson(json);
  Map<String, dynamic> toJson() => _$BrandToJson(this);
}

@JsonSerializable()
class Address {
  int? _addressId;
  int? get id => _addressId;
  double? lat;
  double? lng;
  String? plusCode;
  String? sublocality;
  String? locality;
  String? admin1;
  String? admin2;
  String? country;
  Address();
  static String table = 'address';
  factory Address.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Address()
      .._addressId = map['addressId'] as int?
      ..lat = (map['lat'] as double?)
      ..lng = (map['lng'] as double?)
      ..plusCode = (map['plusCode'] as String?)
      ..sublocality = (map['sublocality'] as String?)
      ..locality = (map['locality'] as String?)
      ..admin1 = (map['admin1'] as String?)
      ..admin2 = (map['admin2'] as String?)
      ..country = (map['country'] as String?);
  }
  static Iterable<Address> fromResult(Result result) =>
      result.map(Address.fromRow);
  static Future<Address?> create(Address address) async {
    final json = address.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Address.fromRow(result.first);
  }

  static Future<Iterable<Address>> filter(
      {required Operation? Function(AddressQuery) where}) async {
    final tt = where(AddressQuery());
    final query = Query.select(
      table: AddressQuery.table,
      columns: AddressQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Address fromJson(Map<String, dynamic> json) => _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

@JsonSerializable()
class Shop {
  int? _shopId;
  int? get id => _shopId;
  String name;
  User owner;
  Address address;
  Catagory? catagory;
  String? logo;
  String? bgImage;
  DateTime createdAt = DateTime.now();
  Shop({required this.name, required this.owner, required this.address});
  static String table = 'shop';
  factory Shop.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Shop(
        name: map['name'] as String,
        owner: User.fromRow(row),
        address: Address.fromRow(row))
      .._shopId = map['shopId'] as int?
      ..name = (map['name'] as String)
      ..owner = User.fromRow(row)
      ..address = Address.fromRow(row)
      ..catagory = Catagory?.fromRow(row)
      ..logo = (map['logo'] as String?)
      ..bgImage = (map['bgImage'] as String?)
      ..createdAt = (map['createdAt'] as DateTime);
  }
  static Iterable<Shop> fromResult(Result result) => result.map(Shop.fromRow);
  static Future<Shop?> create(Shop shop) async {
    final json = shop.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Shop.fromRow(result.first);
  }

  static Future<Iterable<Shop>> filter(
      {required Operation? Function(ShopQuery) where}) async {
    final tt = where(ShopQuery());
    final query = Query.select(
      table: ShopQuery.table,
      columns: ShopQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Shop fromJson(Map<String, dynamic> json) => _$ShopFromJson(json);
  Map<String, dynamic> toJson() => _$ShopToJson(this);
}

@JsonSerializable()
class ShopAcitiviy {
  int? _shopacitiviyId;
  int? get id => _shopacitiviyId;
  User user;
  String? action;
  ShopAcitiviy({required this.user});
  static String table = 'shopacitiviy';
  factory ShopAcitiviy.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return ShopAcitiviy(user: User.fromRow(row))
      .._shopacitiviyId = map['shopacitiviyId'] as int?
      ..user = User.fromRow(row)
      ..action = (map['action'] as String?);
  }
  static Iterable<ShopAcitiviy> fromResult(Result result) =>
      result.map(ShopAcitiviy.fromRow);
  static Future<ShopAcitiviy?> create(ShopAcitiviy shopacitiviy) async {
    final json = shopacitiviy.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : ShopAcitiviy.fromRow(result.first);
  }

  static Future<Iterable<ShopAcitiviy>> filter(
      {required Operation? Function(ShopAcitiviyQuery) where}) async {
    final tt = where(ShopAcitiviyQuery());
    final query = Query.select(
      table: ShopAcitiviyQuery.table,
      columns: ShopAcitiviyQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static ShopAcitiviy fromJson(Map<String, dynamic> json) =>
      _$ShopAcitiviyFromJson(json);
  Map<String, dynamic> toJson() => _$ShopAcitiviyToJson(this);
}

@JsonSerializable()
class ShopReview {
  int? _shopreviewId;
  int? get id => _shopreviewId;
  User user;
  Shop shop;
  ShopReview({required this.user, required this.shop});
  static String table = 'shopreview';
  factory ShopReview.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return ShopReview(user: User.fromRow(row), shop: Shop.fromRow(row))
      .._shopreviewId = map['shopreviewId'] as int?
      ..user = User.fromRow(row)
      ..shop = Shop.fromRow(row);
  }
  static Iterable<ShopReview> fromResult(Result result) =>
      result.map(ShopReview.fromRow);
  static Future<ShopReview?> create(ShopReview shopreview) async {
    final json = shopreview.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : ShopReview.fromRow(result.first);
  }

  static Future<Iterable<ShopReview>> filter(
      {required Operation? Function(ShopReviewQuery) where}) async {
    final tt = where(ShopReviewQuery());
    final query = Query.select(
      table: ShopReviewQuery.table,
      columns: ShopReviewQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static ShopReview fromJson(Map<String, dynamic> json) =>
      _$ShopReviewFromJson(json);
  Map<String, dynamic> toJson() => _$ShopReviewToJson(this);
}

@JsonSerializable()
class Product {
  int? _productId;
  int? get id => _productId;
  String name;
  double buyingPrice;
  double sellingPrice;
  int quantity = 0;
  String? desc;
  Product(
      {required this.name,
      required this.buyingPrice,
      required this.sellingPrice});
  static String table = 'product';
  factory Product.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Product(
        name: map['name'] as String,
        buyingPrice: map['buyingPrice'] as double,
        sellingPrice: map['sellingPrice'] as double)
      .._productId = map['productId'] as int?
      ..name = (map['name'] as String)
      ..buyingPrice = (map['buyingPrice'] as double)
      ..sellingPrice = (map['sellingPrice'] as double)
      ..quantity = (map['quantity'] as int)
      ..desc = (map['desc'] as String?);
  }
  static Iterable<Product> fromResult(Result result) =>
      result.map(Product.fromRow);
  static Future<Product?> create(Product product) async {
    final json = product.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Product.fromRow(result.first);
  }

  static Future<Iterable<Product>> filter(
      {required Operation? Function(ProductQuery) where}) async {
    final tt = where(ProductQuery());
    final query = Query.select(
      table: ProductQuery.table,
      columns: ProductQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Product fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}

@JsonSerializable()
class Like {
  int? _likeId;
  int? get id => _likeId;
  Product product;
  Like({required this.product});
  static String table = 'like';
  factory Like.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Like(product: Product.fromRow(row))
      .._likeId = map['likeId'] as int?
      ..product = Product.fromRow(row);
  }
  static Iterable<Like> fromResult(Result result) => result.map(Like.fromRow);
  static Future<Like?> create(Like like) async {
    final json = like.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Like.fromRow(result.first);
  }

  static Future<Iterable<Like>> filter(
      {required Operation? Function(LikeQuery) where}) async {
    final tt = where(LikeQuery());
    final query = Query.select(
      table: LikeQuery.table,
      columns: LikeQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Like fromJson(Map<String, dynamic> json) => _$LikeFromJson(json);
  Map<String, dynamic> toJson() => _$LikeToJson(this);
}

@JsonSerializable()
class Follow {
  int? _followId;
  int? get id => _followId;
  Shop shop;
  User user;
  Follow({required this.shop, required this.user});
  static String table = 'follow';
  factory Follow.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Follow(shop: Shop.fromRow(row), user: User.fromRow(row))
      .._followId = map['followId'] as int?
      ..shop = Shop.fromRow(row)
      ..user = User.fromRow(row);
  }
  static Iterable<Follow> fromResult(Result result) =>
      result.map(Follow.fromRow);
  static Future<Follow?> create(Follow follow) async {
    final json = follow.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Follow.fromRow(result.first);
  }

  static Future<Iterable<Follow>> filter(
      {required Operation? Function(FollowQuery) where}) async {
    final tt = where(FollowQuery());
    final query = Query.select(
      table: FollowQuery.table,
      columns: FollowQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Follow fromJson(Map<String, dynamic> json) => _$FollowFromJson(json);
  Map<String, dynamic> toJson() => _$FollowToJson(this);
}

@JsonSerializable()
class Order {
  int? _orderId;
  int? get id => _orderId;
  String? status;
  String? type;
  String? msg;
  Shop shop;
  User user;
  Order({required this.shop, required this.user});
  static String table = 'order';
  factory Order.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Order(shop: Shop.fromRow(row), user: User.fromRow(row))
      .._orderId = map['orderId'] as int?
      ..status = (map['status'] as String?)
      ..type = (map['type'] as String?)
      ..msg = (map['msg'] as String?)
      ..shop = Shop.fromRow(row)
      ..user = User.fromRow(row);
  }
  static Iterable<Order> fromResult(Result result) => result.map(Order.fromRow);
  static Future<Order?> create(Order order) async {
    final json = order.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Order.fromRow(result.first);
  }

  static Future<Iterable<Order>> filter(
      {required Operation? Function(OrderQuery) where}) async {
    final tt = where(OrderQuery());
    final query = Query.select(
      table: OrderQuery.table,
      columns: OrderQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Order fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
  Map<String, dynamic> toJson() => _$OrderToJson(this);
}

@JsonSerializable()
class Items {
  int? _itemsId;
  int? get id => _itemsId;
  Product product;
  int quantity = 0;
  Order? order;
  DateTime? createdAt = DateTime.now();
  Items({required this.product});
  static String table = 'items';
  factory Items.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Items(product: Product.fromRow(row))
      .._itemsId = map['itemsId'] as int?
      ..product = Product.fromRow(row)
      ..quantity = (map['quantity'] as int)
      ..order = Order?.fromRow(row)
      ..createdAt = (map['createdAt'] as DateTime?);
  }
  static Iterable<Items> fromResult(Result result) => result.map(Items.fromRow);
  static Future<Items?> create(Items items) async {
    final json = items.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Items.fromRow(result.first);
  }

  static Future<Iterable<Items>> filter(
      {required Operation? Function(ItemsQuery) where}) async {
    final tt = where(ItemsQuery());
    final query = Query.select(
      table: ItemsQuery.table,
      columns: ItemsQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Items fromJson(Map<String, dynamic> json) => _$ItemsFromJson(json);
  Map<String, dynamic> toJson() => _$ItemsToJson(this);
}

@JsonSerializable()
class Notification {
  int? _notificationId;
  int? get id => _notificationId;
  User user;
  DateTime timestamp;
  String title;
  String content;
  String type;
  Notification(
      {required this.user,
      required this.timestamp,
      required this.title,
      required this.content,
      required this.type});
  static String table = 'notification';
  factory Notification.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Notification(
        user: User.fromRow(row),
        timestamp: map['timestamp'] as DateTime,
        title: map['title'] as String,
        content: map['content'] as String,
        type: map['type'] as String)
      .._notificationId = map['notificationId'] as int?
      ..user = User.fromRow(row)
      ..timestamp = (map['timestamp'] as DateTime)
      ..title = (map['title'] as String)
      ..content = (map['content'] as String)
      ..type = (map['type'] as String);
  }
  static Iterable<Notification> fromResult(Result result) =>
      result.map(Notification.fromRow);
  static Future<Notification?> create(Notification notification) async {
    final json = notification.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Notification.fromRow(result.first);
  }

  static Future<Iterable<Notification>> filter(
      {required Operation? Function(NotificationQuery) where}) async {
    final tt = where(NotificationQuery());
    final query = Query.select(
      table: NotificationQuery.table,
      columns: NotificationQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Notification fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationToJson(this);
}

@JsonSerializable()
class GiftCard {
  int? _giftcardId;
  int? get id => _giftcardId;
  String coupon_id;
  User owner;
  User? createdBy;
  Product? product;
  Shop? shop;
  bool? redeemed = false;
  DateTime? expireDate;
  GiftCard({required this.coupon_id, required this.owner});
  static String table = 'giftcard';
  factory GiftCard.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return GiftCard(
        coupon_id: map['coupon_id'] as String, owner: User.fromRow(row))
      .._giftcardId = map['giftcardId'] as int?
      ..coupon_id = (map['coupon_id'] as String)
      ..owner = User.fromRow(row)
      ..createdBy = User?.fromRow(row)
      ..product = Product?.fromRow(row)
      ..shop = Shop?.fromRow(row)
      ..redeemed = (map['redeemed'] as bool?)
      ..expireDate = (map['expireDate'] as DateTime?);
  }
  static Iterable<GiftCard> fromResult(Result result) =>
      result.map(GiftCard.fromRow);
  static Future<GiftCard?> create(GiftCard giftcard) async {
    final json = giftcard.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : GiftCard.fromRow(result.first);
  }

  static Future<Iterable<GiftCard>> filter(
      {required Operation? Function(GiftCardQuery) where}) async {
    final tt = where(GiftCardQuery());
    final query = Query.select(
      table: GiftCardQuery.table,
      columns: GiftCardQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static GiftCard fromJson(Map<String, dynamic> json) =>
      _$GiftCardFromJson(json);
  Map<String, dynamic> toJson() => _$GiftCardToJson(this);
}

@JsonSerializable()
class Blocked {
  int? _blockedId;
  int? get id => _blockedId;
  User? user;
  Shop? shop;
  Product? product;
  DateTime? endDate;
  Blocked();
  static String table = 'blocked';
  factory Blocked.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Blocked()
      .._blockedId = map['blockedId'] as int?
      ..user = User?.fromRow(row)
      ..shop = Shop?.fromRow(row)
      ..product = Product?.fromRow(row)
      ..endDate = (map['endDate'] as DateTime?);
  }
  static Iterable<Blocked> fromResult(Result result) =>
      result.map(Blocked.fromRow);
  static Future<Blocked?> create(Blocked blocked) async {
    final json = blocked.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Blocked.fromRow(result.first);
  }

  static Future<Iterable<Blocked>> filter(
      {required Operation? Function(BlockedQuery) where}) async {
    final tt = where(BlockedQuery());
    final query = Query.select(
      table: BlockedQuery.table,
      columns: BlockedQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Blocked fromJson(Map<String, dynamic> json) => _$BlockedFromJson(json);
  Map<String, dynamic> toJson() => _$BlockedToJson(this);
}

@JsonSerializable()
class Policy {
  int? _policyId;
  int? get id => _policyId;
  int? number;
  String? detail;
  DateTime createdAt = DateTime.now();
  Policy();
  static String table = 'policy';
  factory Policy.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Policy()
      .._policyId = map['policyId'] as int?
      ..number = (map['number'] as int?)
      ..detail = (map['detail'] as String?)
      ..createdAt = (map['createdAt'] as DateTime);
  }
  static Iterable<Policy> fromResult(Result result) =>
      result.map(Policy.fromRow);
  static Future<Policy?> create(Policy policy) async {
    final json = policy.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Policy.fromRow(result.first);
  }

  static Future<Iterable<Policy>> filter(
      {required Operation? Function(PolicyQuery) where}) async {
    final tt = where(PolicyQuery());
    final query = Query.select(
      table: PolicyQuery.table,
      columns: PolicyQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Policy fromJson(Map<String, dynamic> json) => _$PolicyFromJson(json);
  Map<String, dynamic> toJson() => _$PolicyToJson(this);
}

@JsonSerializable()
class Report {
  int? _reportId;
  int? get id => _reportId;
  Policy? policy;
  Shop shop;
  User user;
  User? violator;
  Product? product;
  String? desc;
  Report({required this.shop, required this.user});
  static String table = 'report';
  factory Report.fromRow(ResultRow row) {
    final map = row.toColumnMap();
    return Report(shop: Shop.fromRow(row), user: User.fromRow(row))
      .._reportId = map['reportId'] as int?
      ..policy = Policy?.fromRow(row)
      ..shop = Shop.fromRow(row)
      ..user = User.fromRow(row)
      ..violator = User?.fromRow(row)
      ..product = Product?.fromRow(row)
      ..desc = (map['desc'] as String?);
  }
  static Iterable<Report> fromResult(Result result) =>
      result.map(Report.fromRow);
  static Future<Report?> create(Report report) async {
    final json = report.toJson();
    final conn = await Database().connection;
    final query = Query.insert(table: table, columns: json);
    final result = await conn.runTx((session) {
      return session.execute(query.toString());
    });
    return result.isEmpty ? null : Report.fromRow(result.first);
  }

  static Future<Iterable<Report>> filter(
      {required Operation? Function(ReportQuery) where}) async {
    final tt = where(ReportQuery());
    final query = Query.select(
      table: ReportQuery.table,
      columns: ReportQuery.columns,
      operation: tt,
      joins: tt == null ? [] : tt.joins,
    );
    final conn = await Database().connection;
    final result = await conn.execute(query.toString());
    return fromResult(result);
  }

  static Report fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);
  Map<String, dynamic> toJson() => _$ReportToJson(this);
}
