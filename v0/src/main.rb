require 'json'
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

  KEntityTypeNone = "none"
  KKeyOutputAttributes    = "OutputAttributes"
  KKeyFilterAttributes    = "FilterAttributes"
  KLinePrefixEntityType   = "entity-type"
  KLinePrefixOutputAttrs  = "Output attributes:"
  KLinePrefixFilterAttrs  = "Filter attributes:"
  KParseStateNone             = "none"
  KParseStateEntityType       = "entity-type"
  KParseStateOutputAttributes = "output-attributes"

  def initialize( usernameIn, passwordIn )
    @mvbUsername    = usernameIn
    @mvbPassword    = passwordIn
    @attributesBody = ""
    @attributesParsed = nil
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

    bSuccess = false
    case resGet
      when Net::HTTPSuccess
        @attributesBody = resGet.body
        bSuccess = true
      when Net::HTTPUnauthorized
        logger.error( "ReadAttributes: FAILED.HTTPUnauthorized - username and password set and correct?" )
      when Net::HTTPServerError
        logger.error( "ReadAttributes: FAILED.HTTPServerError - try again later?" )
      else
        logger.error( "ReadAttributes: FAILED.(unknown) - #{response.message}" )
    end

    return bSuccess
  end


  def PrintAttributes
    if !@attributesParsed
      if !parseAttributes()
        logger.error( "PrintAttributes: parseAttributes FAILED" )
      end
    end

    logger.info( "PrintAttributes: attributesParsed: #{@attributesParsed.to_json}")
  end


  private

  def parseAttributes
    if !@attributesBody
      @attributesParsed = nil
      return false
    end

    @attributesParsed = {}
    asLines = @attributesBody.split( /\n/ )
    parseState  = KParseStateNone
    entityType  = KEntityTypeNone

    asLines.each do |oneLine|
      #logger.info( "parseState: #{parseState}  oneLine: #{oneLine}")

      case parseState
      when KParseStateNone
        # Looking for Output "entity-type"
        if oneLine.start_with?( KLinePrefixEntityType )
          # entity-type=study
          asPair  = oneLine.split( "=" )
          if 2 != asPair.length()
            logger.error( "parseAttributes: MALFORMED asPair=#{asPair}" )
          end

          parseState  = KParseStateEntityType
          entityType  = asPair[1]
          logger.info( "parseState: #{parseState}  entityType=#{entityType}")
        # else
        #   logger.info( "parseState: #{parseState}  dump and continue: #{oneLine}")
        end

      when KParseStateEntityType
        # We saw the entity-type line, now looking for "Output attributes"
        if oneLine.start_with?( KLinePrefixOutputAttrs )
          attrsString = oneLine[ KLinePrefixOutputAttrs.length..-1 ]
          attrsList   = attrsString.split( "," ).map( &:strip )
          #logger.info( "KLinePrefixOutputAttrs - attrsList: #{attrsList}")
          @attributesParsed[ entityType ] = { KKeyOutputAttributes => attrsList }
          parseState  = KParseStateOutputAttributes
        else
          logger.error( "parseAttributes: expecting Output attributes, UNEXPECTED oneLine=#{oneLine}" )
          parseState  = KParseStateNone
        end

      when KParseStateOutputAttributes
        # We saw the Output Attributes line, now looking for "Filter attributes"
        if oneLine.start_with?( KLinePrefixFilterAttrs )
          attrsString = oneLine[ KLinePrefixFilterAttrs.length..-1 ]
          attrsList   = attrsString.split( "," ).map( &:strip )
          #logger.info( "KLinePrefixFilterAttrs - attrsList: #{attrsList}")
          @attributesParsed[ entityType ][ KKeyFilterAttributes ] = attrsList
          parseState  = KParseStateNone
        else
          logger.error( "parseAttributes: expecting Filter attributes, UNEXPECTED oneLine=#{oneLine}" )
          parseState  = KParseStateNone
        end

      end
    end

    return true
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

mvbank  = MovebankAPI.new( myConfig[ "movebank" ][ "user" ], myConfig[ "movebank" ][ "password" ])

if mvbank.ReadAttributes()
  mvbank.PrintAttributes()
else
  logger.info( "mvbank.ReadAttributes: FAILED" )
end
