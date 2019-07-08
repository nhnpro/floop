
class Base {}

class A extends Base {
  foo() {
    print('Foo on A');
  }
}

class A2 extends A {
  foo() {
    
    print('Foo on A2');
  }
}

mixin Mix on A {
  @override
  foo() {
    print('Foo on Mix');
    super.foo();
  }
}

abstract class B extends A {}

abstract class C = A2 with Mix;

// class C extends B with Mix {}

main() {


}
