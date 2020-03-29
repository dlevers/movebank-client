require 'logger'
require 'net/http'

# class MyClass
#   def say_hello
#     puts "Hello World"
#   end
# end
class MovementAPI
end

# def another_hello
#   puts "Hello World (from a method)"
# end

logger = Logger.new( STDOUT )
logger.info( "main: hello" )

# c = MyClass.new
# c.say_hello
# another_hello

myConfig  = { "user" => "",
            "password" => "" }

ARGV.each do |oneArg|
  asPair  = oneArg.split("=")
  if 2 != asPair.length()
    logger.error( "main: MALFORMED oneArg: #{oneArg}" )
    logger.error( "      all arguments should be \"key=value\"" )
  else
    # logger.info( "main: oneArg: #{oneArg}" )
    if asPair[0] == "u"
      myConfig[ "user" ]  = asPair[1]
    elsif asPair[0] == "p"
      myConfig[ "password" ]  = asPair[1]
    else
      logger.error( "main: UNKNOWN oneArg: #{oneArg}" )
    end
  end
end

logger.info( "main: myConfig: #{myConfig}" )
