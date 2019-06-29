# floop

A new Flutter package project.

## Getting Started

This project is a starting point for a Dart
[package](https://flutter.dev/developing-packages/),
a library module containing code that can be shared easily across
multiple Flutter or Dart projects.

For help getting started with Flutter, view our 
[online documentation](https://flutter.dev/docs), which offers tutorials, 
samples, guidance on mobile development, and a full API reference.




Allow wrapping class instances to catch method calls, using mixins or wrappers

Currently I miss a way to wrap class instances, so it's possible to catch calls to their methods. Even more ambitious is to be able to "override" their methods by creating new objects that wraps the instance and defers methods which are not defined in the wrapper to the o. This flexibility would be extremely useful to create libraries that extend existing libraries or frameworks when you don't have access to the class definitions. It's also useful for testing.

The core functionality I expect is a way of catching when methods of a class instace are called. Something on the lines of:

class A {
  T foo(int n) { return '' }
}

wrapper W on A {
  before foo(int n) { foo } // called as soon as foo is called

  after foo(T fooResult) { } // called when foo finishes
}

A a = A();
W.wrap(a);  // or it could be W(a)

a.foo(5)  // calls in order 'before foo'(5), foo(5), 'after foo'(fooResult)


A more flexible solution is to be able to modify the functions:

class A {
  T foo() { }

  P toc() { }
}

wrapper W on A {
  @override
  T foo() { super.foo() /* more code */ }

  Q bar() { }
}

A a = A();
W w = W.wrap(a);

a.foo()  // calls foo defined in wrapper W
a.bar()  // compile error
a.toc()  // calls toc defined in A

w.foo()  // calls foo defined in wrapper W
w.bar()  // calls bar defined in wrapper W
w.toc()  // calls toc defined in A

Having this feature would give more freedom and dynamism to the language. I was trying to create small library for flutter and I found myself unable to do what I wanted unless I modified the library itself.

Currently it is possible to achieve this behavior, but it is very cumberstone, verbose and more "dangerous" than what a potential wrapper would be, because you can "downcast" variables. Currently we could do:


The alternative is to create a more complicated library where multiple mixin versions for every different subclass that implement the mixins

There are several options to approach such a feature, some more conservatives than the others. Here are few options:



