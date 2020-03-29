require 'logger'

class MyClass
  def say_hello
    puts "Hello World"
  end
end

def another_hello
  puts "Hello World (from a method)"
end

logger = Logger.new( STDOUT )
logger.info( "main: hello" )

c = MyClass.new
c.say_hello
another_hello
