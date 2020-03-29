require 'logger'
require 'net/http'


module Logging
  def logger
    @logger ||= Logging.logger_for( self.class.name )
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self
    def logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    def configure_logger_for(classname)
      logger = Logger.new(STDOUT)
      logger.progname = classname
      logger
    end
  end
end


# class MyClass
#   def say_hello
#     puts "Hello World"
#   end
# end
class MovebankAPI
  include Logging

  def initialize( usernameIn, passwordIn )
    @mvbUsername  = usernameIn
    @mvbPassword  = passwordIn
  end


  def ReadAttributes
    # curl -v -u dlevers:stANley6 -b cookies.txt -o attribute_names.txt "https://www.movebank.org/movebank/service/direct-read?attributes"
    uri     = URI( 'https://www.movebank.org/movebank/service/direct-read?attributes' )
    # resultGet = Net::HTTP.get( uri )
    # logger.info( "resultGet: #{resultGet}" )
    req     = Net::HTTP::Get.new( uri )
    req.basic_auth( @mvbUsername, @mvbPassword )

    resGet  = Net::HTTP.start( uri.hostname,
                            uri.port,
                            :use_ssl => uri.scheme == 'https' ) { |http|
      http.request( req )
    }
    logger.info( "resGet.body: #{resGet.body}" )
  end
end


# def another_hello
#   puts "Hello World (from a method)"
# end

# logger = Logger.new( STDOUT )
logger  = Logging.logger_for( "main" )
logger.info( "main: hello" )

# c = MyClass.new
# c.say_hello
# another_hello

myConfig  = { "movebank" => { "user" => "",
                            "password" => "" }}

ARGV.each do |oneArg|
  asPair  = oneArg.split("=")
  if 2 != asPair.length()
    logger.error( "MALFORMED oneArg: #{oneArg}" )
    logger.error( "      all arguments should be \"key=value\"" )
  else
    # logger.info( "main: oneArg: #{oneArg}" )
    if asPair[0] == "u"
      myConfig[ "movebank" ][ "user" ]  = asPair[1]
    elsif asPair[0] == "p"
      myConfig[ "movebank" ][ "password" ]  = asPair[1]
    else
      logger.error( "UNKNOWN oneArg: #{oneArg}" )
    end
  end
end

logger.info( "myConfig: #{myConfig}" )

mvmt  = MovebankAPI.new( myConfig[ "movebank" ][ "user" ], myConfig[ "movebank" ][ "password" ])

mvmt.ReadAttributes()
