require 'logger'
require 'net/http'

# class MyClass
#   def say_hello
#     puts "Hello World"
#   end
# end
class MovebankAPI
  def initialize( usernameIn, passwordIn )
    @mvbUsername  = usernameIn
    @mvbPassword  = passwordIn
  end


  def ReadAttributes
    curl -v -u dlevers:stANley6 -b cookies.txt -o attribute_names.txt "https://www.movebank.org/movebank/service/direct-read?attributes"
  end
end


# def another_hello
#   puts "Hello World (from a method)"
# end

logger = Logger.new( STDOUT )
logger.info( "main: hello" )

# c = MyClass.new
# c.say_hello
# another_hello

myConfig  = { "movebank" => { "user" => "",
                            "password" => "" }}

ARGV.each do |oneArg|
  asPair  = oneArg.split("=")
  if 2 != asPair.length()
    logger.error( "main: MALFORMED oneArg: #{oneArg}" )
    logger.error( "      all arguments should be \"key=value\"" )
  else
    # logger.info( "main: oneArg: #{oneArg}" )
    if asPair[0] == "u"
      myConfig[ "movebank" ][ "user" ]  = asPair[1]
    elsif asPair[0] == "p"
      myConfig[ "movebank" ][ "password" ]  = asPair[1]
    else
      logger.error( "main: UNKNOWN oneArg: #{oneArg}" )
    end
  end
end

logger.info( "main: myConfig: #{myConfig}" )

mvmt  = MovebankAPI.new( myConfig[ "movebank" ][ "user" ], myConfig[ "movebank" ][ "password" ])

mvmt.ReadAttributes()
