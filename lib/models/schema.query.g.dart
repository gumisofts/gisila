part of 'schema.dart';

class FileTbQuery {
  FileTbQuery();
  factory FileTbQuery.referenced({required List<Join> joins}) =>
      FileTbQuery().._joins.addAll(joins);
  static const table = 'filetb';
  NumberColumn get id => NumberColumn(column: 'filetbId', offtable: 'filetb');
  TextColumn get url =>
      TextColumn(column: 'url', offtable: 'filetb', depends: _joins);
  TextColumn get isAbsolute =>
      TextColumn(column: 'isAbsolute', offtable: 'filetb', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>['filetbId', 'url', 'isAbsolute'];
}

class UserQuery {
  UserQuery();
  factory UserQuery.referenced({required List<Join> joins}) =>
      UserQuery().._joins.addAll(joins);
  static const table = 'user';
  NumberColumn get id => NumberColumn(column: 'userId', offtable: 'user');
  TextColumn get firstName =>
      TextColumn(column: 'firstName', offtable: 'user', depends: _joins);
  TextColumn get lastName =>
      TextColumn(column: 'lastName', offtable: 'user', depends: _joins);
  TextColumn get phoneNumber =>
      TextColumn(column: 'phoneNumber', offtable: 'user', depends: _joins);
  TextColumn get email =>
      TextColumn(column: 'email', offtable: 'user', depends: _joins);
  TextColumn get createdAt =>
      TextColumn(column: 'createdAt', offtable: 'user', depends: _joins);
  TextColumn get updatedAt =>
      TextColumn(column: 'updatedAt', offtable: 'user', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'userId',
        'firstName',
        'lastName',
        'phoneNumber',
        'email',
        'createdAt',
        'updatedAt',
      ];
}

class PasswordQuery {
  PasswordQuery();
  factory PasswordQuery.referenced({required List<Join> joins}) =>
      PasswordQuery().._joins.addAll(joins);
  static const table = 'password';
  NumberColumn get id =>
      NumberColumn(column: 'passwordId', offtable: 'password');
  TextColumn get password =>
      TextColumn(column: 'password', offtable: 'password', depends: _joins);
  TextColumn get emailOtp =>
      TextColumn(column: 'emailOtp', offtable: 'password', depends: _joins);
  TextColumn get phoneOtp =>
      TextColumn(column: 'phoneOtp', offtable: 'password', depends: _joins);
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['passwordId', 'password', 'emailOtp', 'phoneOtp', 'user'];
}

class UserInterestAndInteractionQuery {
  UserInterestAndInteractionQuery();
  factory UserInterestAndInteractionQuery.referenced(
          {required List<Join> joins,}) =>
      UserInterestAndInteractionQuery().._joins.addAll(joins);
  static const table = 'userinterestandinteraction';
  NumberColumn get id => NumberColumn(
      column: 'userinterestandinteractionId',
      offtable: 'userinterestandinteraction',);
  CatagoryQuery get catagory => CatagoryQuery.referenced(joins: [
        ..._joins,
        Join(table: 'catagory', onn: 'catagory', from: table),
      ],);
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['userinterestandinteractionId', 'catagory', 'user'];
}

class CatagoryQuery {
  CatagoryQuery();
  factory CatagoryQuery.referenced({required List<Join> joins}) =>
      CatagoryQuery().._joins.addAll(joins);
  static const table = 'catagory';
  NumberColumn get id =>
      NumberColumn(column: 'catagoryId', offtable: 'catagory');
  TextColumn get name =>
      TextColumn(column: 'name', offtable: 'catagory', depends: _joins);
  TextColumn get desc =>
      TextColumn(column: 'desc', offtable: 'catagory', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>['catagoryId', 'name', 'desc'];
}

class BrandQuery {
  BrandQuery();
  factory BrandQuery.referenced({required List<Join> joins}) =>
      BrandQuery().._joins.addAll(joins);
  static const table = 'brand';
  NumberColumn get id => NumberColumn(column: 'brandId', offtable: 'brand');
  TextColumn get name =>
      TextColumn(column: 'name', offtable: 'brand', depends: _joins);
  CatagoryQuery get catagory => CatagoryQuery.referenced(joins: [
        ..._joins,
        Join(table: 'catagory', onn: 'catagory', from: table),
      ],);
  TextColumn get desc =>
      TextColumn(column: 'desc', offtable: 'brand', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['brandId', 'name', 'catagory', 'desc'];
}

class AddressQuery {
  AddressQuery();
  factory AddressQuery.referenced({required List<Join> joins}) =>
      AddressQuery().._joins.addAll(joins);
  static const table = 'address';
  NumberColumn get id => NumberColumn(column: 'addressId', offtable: 'address');
  NumberColumn get lat =>
      NumberColumn(column: 'lat', offtable: 'address', depends: _joins);
  NumberColumn get lng =>
      NumberColumn(column: 'lng', offtable: 'address', depends: _joins);
  TextColumn get plusCode =>
      TextColumn(column: 'plusCode', offtable: 'address', depends: _joins);
  TextColumn get sublocality =>
      TextColumn(column: 'sublocality', offtable: 'address', depends: _joins);
  TextColumn get locality =>
      TextColumn(column: 'locality', offtable: 'address', depends: _joins);
  TextColumn get admin1 =>
      TextColumn(column: 'admin1', offtable: 'address', depends: _joins);
  TextColumn get admin2 =>
      TextColumn(column: 'admin2', offtable: 'address', depends: _joins);
  TextColumn get country =>
      TextColumn(column: 'country', offtable: 'address', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'addressId',
        'lat',
        'lng',
        'plusCode',
        'sublocality',
        'locality',
        'admin1',
        'admin2',
        'country',
      ];
}

class ShopQuery {
  ShopQuery();
  factory ShopQuery.referenced({required List<Join> joins}) =>
      ShopQuery().._joins.addAll(joins);
  static const table = 'shop';
  NumberColumn get id => NumberColumn(column: 'shopId', offtable: 'shop');
  TextColumn get name =>
      TextColumn(column: 'name', offtable: 'shop', depends: _joins);
  UserQuery get owner => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'owner', from: table),
      ],);
  AddressQuery get address => AddressQuery.referenced(joins: [
        ..._joins,
        Join(table: 'address', onn: 'address', from: table),
      ],);
  CatagoryQuery get catagory => CatagoryQuery.referenced(joins: [
        ..._joins,
        Join(table: 'catagory', onn: 'catagory', from: table),
      ],);
  TextColumn get logo =>
      TextColumn(column: 'logo', offtable: 'shop', depends: _joins);
  TextColumn get bgImage =>
      TextColumn(column: 'bgImage', offtable: 'shop', depends: _joins);
  TextColumn get createdAt =>
      TextColumn(column: 'createdAt', offtable: 'shop', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'shopId',
        'name',
        'owner',
        'address',
        'catagory',
        'logo',
        'bgImage',
        'createdAt',
      ];
}

class ShopPrefrencesQuery {
  ShopPrefrencesQuery();
  factory ShopPrefrencesQuery.referenced({required List<Join> joins}) =>
      ShopPrefrencesQuery().._joins.addAll(joins);
  static const table = 'shopprefrences';
  NumberColumn get id =>
      NumberColumn(column: 'shopprefrencesId', offtable: 'shopprefrences');
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  TextColumn get isAvailableOnline => TextColumn(
      column: 'isAvailableOnline', offtable: 'shopprefrences', depends: _joins,);
  TextColumn get notifyNewProduct => TextColumn(
      column: 'notifyNewProduct', offtable: 'shopprefrences', depends: _joins,);
  TextColumn get receiveOrder => TextColumn(
      column: 'receiveOrder', offtable: 'shopprefrences', depends: _joins,);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'shopprefrencesId',
        'shop',
        'isAvailableOnline',
        'notifyNewProduct',
        'receiveOrder',
      ];
}

class ShopAcitiviyQuery {
  ShopAcitiviyQuery();
  factory ShopAcitiviyQuery.referenced({required List<Join> joins}) =>
      ShopAcitiviyQuery().._joins.addAll(joins);
  static const table = 'shopacitiviy';
  NumberColumn get id =>
      NumberColumn(column: 'shopacitiviyId', offtable: 'shopacitiviy');
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  TextColumn get action =>
      TextColumn(column: 'action', offtable: 'shopacitiviy', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['shopacitiviyId', 'user', 'action'];
}

class ShopReviewQuery {
  ShopReviewQuery();
  factory ShopReviewQuery.referenced({required List<Join> joins}) =>
      ShopReviewQuery().._joins.addAll(joins);
  static const table = 'shopreview';
  NumberColumn get id =>
      NumberColumn(column: 'shopreviewId', offtable: 'shopreview');
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  final _joins = <Join>[];
  static List<String> get columns => <String>['shopreviewId', 'user', 'shop'];
}

class ProductQuery {
  ProductQuery();
  factory ProductQuery.referenced({required List<Join> joins}) =>
      ProductQuery().._joins.addAll(joins);
  static const table = 'product';
  NumberColumn get id => NumberColumn(column: 'productId', offtable: 'product');
  TextColumn get name =>
      TextColumn(column: 'name', offtable: 'product', depends: _joins);
  NumberColumn get buyingPrice =>
      NumberColumn(column: 'buyingPrice', offtable: 'product', depends: _joins);
  NumberColumn get sellingPrice => NumberColumn(
      column: 'sellingPrice', offtable: 'product', depends: _joins,);
  NumberColumn get quantity =>
      NumberColumn(column: 'quantity', offtable: 'product', depends: _joins);
  TextColumn get desc =>
      TextColumn(column: 'desc', offtable: 'product', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'productId',
        'name',
        'buyingPrice',
        'sellingPrice',
        'quantity',
        'desc',
      ];
}

class LikeQuery {
  LikeQuery();
  factory LikeQuery.referenced({required List<Join> joins}) =>
      LikeQuery().._joins.addAll(joins);
  static const table = 'like';
  NumberColumn get id => NumberColumn(column: 'likeId', offtable: 'like');
  ProductQuery get product => ProductQuery.referenced(joins: [
        ..._joins,
        Join(table: 'product', onn: 'product', from: table),
      ],);
  final _joins = <Join>[];
  static List<String> get columns => <String>['likeId', 'product'];
}

class FollowQuery {
  FollowQuery();
  factory FollowQuery.referenced({required List<Join> joins}) =>
      FollowQuery().._joins.addAll(joins);
  static const table = 'follow';
  NumberColumn get id => NumberColumn(column: 'followId', offtable: 'follow');
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  final _joins = <Join>[];
  static List<String> get columns => <String>['followId', 'shop', 'user'];
}

class OrderQuery {
  OrderQuery();
  factory OrderQuery.referenced({required List<Join> joins}) =>
      OrderQuery().._joins.addAll(joins);
  static const table = 'order';
  NumberColumn get id => NumberColumn(column: 'orderId', offtable: 'order');
  TextColumn get status =>
      TextColumn(column: 'status', offtable: 'order', depends: _joins);
  TextColumn get type =>
      TextColumn(column: 'type', offtable: 'order', depends: _joins);
  TextColumn get msg =>
      TextColumn(column: 'msg', offtable: 'order', depends: _joins);
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['orderId', 'status', 'type', 'msg', 'shop', 'user'];
}

class ItemsQuery {
  ItemsQuery();
  factory ItemsQuery.referenced({required List<Join> joins}) =>
      ItemsQuery().._joins.addAll(joins);
  static const table = 'items';
  NumberColumn get id => NumberColumn(column: 'itemsId', offtable: 'items');
  ProductQuery get product => ProductQuery.referenced(joins: [
        ..._joins,
        Join(table: 'product', onn: 'product', from: table),
      ],);
  NumberColumn get quantity =>
      NumberColumn(column: 'quantity', offtable: 'items', depends: _joins);
  OrderQuery get order => OrderQuery.referenced(joins: [
        ..._joins,
        Join(table: 'order', onn: 'order', from: table),
      ],);
  TextColumn get createdAt =>
      TextColumn(column: 'createdAt', offtable: 'items', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['itemsId', 'product', 'quantity', 'order', 'createdAt'];
}

class NotificationQuery {
  NotificationQuery();
  factory NotificationQuery.referenced({required List<Join> joins}) =>
      NotificationQuery().._joins.addAll(joins);
  static const table = 'notification';
  NumberColumn get id =>
      NumberColumn(column: 'notificationId', offtable: 'notification');
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  TextColumn get timestamp => TextColumn(
      column: 'timestamp', offtable: 'notification', depends: _joins,);
  TextColumn get title =>
      TextColumn(column: 'title', offtable: 'notification', depends: _joins);
  TextColumn get content =>
      TextColumn(column: 'content', offtable: 'notification', depends: _joins);
  TextColumn get type =>
      TextColumn(column: 'type', offtable: 'notification', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'notificationId',
        'user',
        'timestamp',
        'title',
        'content',
        'type',
      ];
}

class GiftCardQuery {
  GiftCardQuery();
  factory GiftCardQuery.referenced({required List<Join> joins}) =>
      GiftCardQuery().._joins.addAll(joins);
  static const table = 'giftcard';
  NumberColumn get id =>
      NumberColumn(column: 'giftcardId', offtable: 'giftcard');
  TextColumn get couponId =>
      TextColumn(column: 'couponId', offtable: 'giftcard', depends: _joins);
  UserQuery get owner => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'owner', from: table),
      ],);
  UserQuery get createdBy => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'createdBy', from: table),
      ],);
  ProductQuery get product => ProductQuery.referenced(joins: [
        ..._joins,
        Join(table: 'product', onn: 'product', from: table),
      ],);
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  TextColumn get redeemed =>
      TextColumn(column: 'redeemed', offtable: 'giftcard', depends: _joins);
  TextColumn get expireDate =>
      TextColumn(column: 'expireDate', offtable: 'giftcard', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'giftcardId',
        'couponId',
        'owner',
        'createdBy',
        'product',
        'shop',
        'redeemed',
        'expireDate',
      ];
}

class BlockedQuery {
  BlockedQuery();
  factory BlockedQuery.referenced({required List<Join> joins}) =>
      BlockedQuery().._joins.addAll(joins);
  static const table = 'blocked';
  NumberColumn get id => NumberColumn(column: 'blockedId', offtable: 'blocked');
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  ProductQuery get product => ProductQuery.referenced(joins: [
        ..._joins,
        Join(table: 'product', onn: 'product', from: table),
      ],);
  TextColumn get endDate =>
      TextColumn(column: 'endDate', offtable: 'blocked', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['blockedId', 'user', 'shop', 'product', 'endDate'];
}

class PolicyQuery {
  PolicyQuery();
  factory PolicyQuery.referenced({required List<Join> joins}) =>
      PolicyQuery().._joins.addAll(joins);
  static const table = 'policy';
  NumberColumn get id => NumberColumn(column: 'policyId', offtable: 'policy');
  NumberColumn get number =>
      NumberColumn(column: 'number', offtable: 'policy', depends: _joins);
  TextColumn get detail =>
      TextColumn(column: 'detail', offtable: 'policy', depends: _joins);
  TextColumn get createdAt =>
      TextColumn(column: 'createdAt', offtable: 'policy', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns =>
      <String>['policyId', 'number', 'detail', 'createdAt'];
}

class ReportQuery {
  ReportQuery();
  factory ReportQuery.referenced({required List<Join> joins}) =>
      ReportQuery().._joins.addAll(joins);
  static const table = 'report';
  NumberColumn get id => NumberColumn(column: 'reportId', offtable: 'report');
  PolicyQuery get policy => PolicyQuery.referenced(joins: [
        ..._joins,
        Join(table: 'policy', onn: 'policy', from: table),
      ],);
  ShopQuery get shop => ShopQuery.referenced(joins: [
        ..._joins,
        Join(table: 'shop', onn: 'shop', from: table),
      ],);
  UserQuery get user => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'user', from: table),
      ],);
  UserQuery get violator => UserQuery.referenced(joins: [
        ..._joins,
        Join(table: 'user', onn: 'violator', from: table),
      ],);
  ProductQuery get product => ProductQuery.referenced(joins: [
        ..._joins,
        Join(table: 'product', onn: 'product', from: table),
      ],);
  TextColumn get desc =>
      TextColumn(column: 'desc', offtable: 'report', depends: _joins);
  final _joins = <Join>[];
  static List<String> get columns => <String>[
        'reportId',
        'policy',
        'shop',
        'user',
        'violator',
        'product',
        'desc',
      ];
}
