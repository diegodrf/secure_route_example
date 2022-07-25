import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const secretKey = '198e1hhcih20hinc2j-';
const address = '0.0.0.0';
const port = 8080;

class CustomMiddlerwares {
  static Middleware get securityMiddleware =>
      createMiddleware(requestHandler: (req) {
        try {
          final authorizationKey = req.headers.keys.firstWhere(
              (element) => element.toLowerCase() == 'authorization');
          final accessToken = (req.headers[authorizationKey] as String)
              .substring('Bearer '.length);
          JWT.verify(accessToken, SecretKey(secretKey));
          return null;
        } catch (e) {
          return Response(HttpStatus.unauthorized);
        }
      });

  static Middleware get jsonMiddleware =>
      createMiddleware(responseHandler: (resp) {
        final jsonHeaders = {HttpHeaders.contentTypeHeader: 'application/json'};
        final newResponse = resp.change(headers: jsonHeaders);
        return newResponse;
      });
}

abstract class BaseController {
  Handler getHandler({bool isSecure = false, List<Middleware>? middlewares});

  Handler createHandler(Handler route,
      {bool isSecure = false, List<Middleware>? middlewares}) {
    middlewares ??= [];

    if (isSecure) {
      middlewares.add(CustomMiddlerwares.securityMiddleware);
    }

    Pipeline pipeline = Pipeline();
    for (final middleware in middlewares) {
      pipeline = pipeline.addMiddleware(middleware);
    }
    pipeline = pipeline.addMiddleware(CustomMiddlerwares.jsonMiddleware);
    return pipeline.addHandler(route);
  }
}

class AuthenticationController extends BaseController {
  @override
  Handler getHandler({bool isSecure = false, List<Middleware>? middlewares}) {
    final Router router = Router();
    router.post('/auth/token', (Request request) async {
      final auth = JWT({'user': 'testuser'});
      final accessToken = auth.sign(SecretKey(secretKey));
      final response = {'accessToken': accessToken};
      return Response.ok(jsonEncode(response));
    });

    return createHandler(router, isSecure: isSecure, middlewares: middlewares);
  }
}

class BooksController extends BaseController {
  @override
  Handler getHandler({bool isSecure = false, List<Middleware>? middlewares}) {
    final Router router = Router();
    router.get('/books', (Request request) async {
      final books = {
        'books': ['book1', 'book2']
      };
      return Response.ok(jsonEncode(books));
    });

    return createHandler(router, isSecure: isSecure, middlewares: middlewares);
  }
}

class CustomServer {
  static Future<HttpServer> init() async {
    Handler cascadeHandler = Cascade()
        .add(AuthenticationController().getHandler())
        .add(BooksController().getHandler(isSecure: true))
        .handler;

    final server = shelf_io.serve(cascadeHandler, address, port);
    print('Running on http://$address:$port');
    return await server;
  }
}
