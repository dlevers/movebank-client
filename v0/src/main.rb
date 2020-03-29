require 'csv'
require 'config'
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

    def configure_logger_for( classname )
      logger          = Logger.new( STDOUT )
      logger.progname = classname
      # logger
      logger.level    = Logger::INFO
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

  # For attributes
  KEntityTypeNone = "none"
  KKeyOutputAttributes    = "OutputAttributes"
  KKeyFilterAttributes    = "FilterAttributes"
  KLinePrefixEntityType   = "entity-type"
  KLinePrefixOutputAttrs  = "Output attributes:"
  KLinePrefixFilterAttrs  = "Filter attributes:"
  KParseStateNone             = "none"
  KParseStateEntityType       = "entity-type"
  KParseStateOutputAttributes = "output-attributes"

  # For studies
  #acknowledgements	citation	create_ts	event_grace_period	go_public_date	go_public_license_type	grants_used	has_quota	i_am_owner	id	is_test	license_terms	license_type	main_location_lat	main_location_long	name	number_of_deployments	number_of_individuals	number_of_tags	principal_investigator_address	principal_investigator_email	principal_investigator_name	study_objective	study_type	suspend_go_public_date	suspend_license_terms	i_can_see_data	there_are_data_which_i_cannot_see	timestamp_first_deployed_location	timestamp_last_deployed_location	number_of_deployed_locations	taxon_ids	sensor_type_ids
  KStudyKeyDeployments    = "number_of_deployments"
  KStudyKeyICanSee        = "i_can_see_data"
  KStudyKeyICannotSeeSome = "there_are_data_which_i_cannot_see"
  KStudyKeyID             = "id"
  KStudyKeyIndividuals    = "number_of_individuals"
  KStudyKeyIsTest         = "is_test"
  KStudyKeyLicenseTerms   = "license_terms"
  KStudyKeyMainLocLatitude  = "main_location_lat"
  KStudyKeyMainLocLongitude = "main_location_long"
  KStudyKeyName             = "name"
  KStudyKeyTags             = "number_of_tags"

  def initialize( usernameIn, passwordIn )
    @mvbUsername    = usernameIn
    @mvbPassword    = passwordIn
    @attributesBody = ""
    @attributesParsed = nil
    @studiesBody    = ""
    @studiesParsed  = nil
  end


  def ReadAttributes
    # curl -v -u dlevers:stANley6 -b cookies.txt -o attribute_names.txt "https://www.movebank.org/movebank/service/direct-read?attributes"
    resRequest  = submitRequest( "https://www.movebank.org/movebank/service/direct-read?attributes" )
    # uri     = URI( 'https://www.movebank.org/movebank/service/direct-read?attributes' )
    # req     = Net::HTTP::Get.new( uri )
    # req.basic_auth( @mvbUsername, @mvbPassword )

    # resGet  = Net::HTTP.start( uri.hostname,
    #                         uri.port,
    #                         :use_ssl => uri.scheme == 'https' ) { |http|
    #   http.request( req )
    # }

    # bSuccess = false
    # case resGet
    #   when Net::HTTPSuccess
    #     @attributesBody = resGet.body
    #     bSuccess = true
    #   when Net::HTTPUnauthorized
    #     logger.error( "ReadAttributes: FAILED.HTTPUnauthorized - username and password set and correct?" )
    #   when Net::HTTPServerError
    #     logger.error( "ReadAttributes: FAILED.HTTPServerError - try again later?" )
    #   else
    #     logger.error( "ReadAttributes: FAILED.(unknown) - #{response.message}" )
    # end
    if resRequest.kind_of?( Net::HTTPSuccess )
      @attributesBody = resRequest.body
      if !parseAttributes()
        logger.error( "ReadAttributes: parseAttributes FAILED" )
      end
      return true
    end

    return false
  end


  def ReadStudies
    # Get a list of studies
    resRequest  = submitRequest( "https://www.movebank.org/movebank/service/direct-read?entity_type=study" )
    if resRequest.kind_of?( Net::HTTPSuccess )
      @studiesBody = resRequest.body
      if !parseStudies()
        logger.error( "ReadStudies: parseStudies FAILED" )
      end
      return true
    end

    return false
  end


  def PrintAttributes
    if !@attributesParsed
      if !parseAttributes()
        logger.error( "PrintAttributes: parseAttributes FAILED" )
      end
    end

    logger.debug( "PrintAttributes: attributesParsed: #{@attributesParsed.to_json}")
  end


  def PrintStudies( descFilterIn )
    if !@studiesParsed
      if !parseStudies()
        logger.error( "PrintStudies: parseStudies FAILED" )
      end
    end

    countCanSee     = 0
    countCannotSee  = 0
    @studiesParsed.each_value do |oneStudy|
      offset  = oneStudy.field( KStudyKeyName ).match( /#{descFilterIn}/i )
      if offset
        if "true" == oneStudy.field( KStudyKeyICanSee )
          countCanSee += 1
          logger.info( "PrintStudies: matching #{descFilterIn}  study id=#{oneStudy.field( KStudyKeyID )}  is_test: #{oneStudy.field( KStudyKeyIsTest )}" )
          logger.info( "                      name: #{oneStudy.field( KStudyKeyName )}" )
          logger.info( "                      i_can_see=#{oneStudy.field( KStudyKeyICanSee )}  some_cannot_see=#{oneStudy.field( KStudyKeyICannotSeeSome )}" )
          logger.info( "                      main location lat=#{oneStudy.field( KStudyKeyMainLocLatitude )}  long=#{oneStudy.field( KStudyKeyMainLocLongitude )}" )
          logger.info( "                      deployments=#{oneStudy.field( KStudyKeyDeployments )}  individuals=#{oneStudy.field( KStudyKeyIndividuals )}  tags=#{oneStudy.field( KStudyKeyTags )}" )
          if oneStudy.field( KStudyKeyLicenseTerms ) && oneStudy.field( KStudyKeyLicenseTerms ).length > 2
            logger.info( "                      license terms: #{oneStudy.field( KStudyKeyLicenseTerms )}" )
          end
        else
          countCannotSee += 1
        end
      end
    end

    logger.info( "PrintStudies: descFilterIn=#{descFilterIn}  can/cannot see: #{countCanSee}/#{countCannotSee}" )
  end


  private

  def submitRequest( urlStringIn )
    uri     = URI( urlStringIn )
    req     = Net::HTTP::Get.new( uri )
    req.basic_auth( @mvbUsername, @mvbPassword )

    resGet  = Net::HTTP.start( uri.hostname,
                            uri.port,
                            :use_ssl => uri.scheme == 'https' ) { |http|
      http.request( req )
    }

    case resGet
      when Net::HTTPSuccess
        logger.debug( "submitRequest: Net::HTTPSuccess" )
      when Net::HTTPUnauthorized
        logger.error( "submitRequest: FAILED.HTTPUnauthorized - username and password set and correct?" )
      when Net::HTTPServerError
        logger.error( "submitRequest: FAILED.HTTPServerError - try again later?" )
      else
        logger.error( "submitRequest: FAILED.(unknown) - #{resGet.message}" )
    end

    return resGet
  end


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


  def parseStudies
    if !@studiesBody
      @studiesParsed = nil
      return false
    end

    @studiesParsed = {}
    # logger.info( "parseStudies: studiesBody: #{@studiesBody}" )
    # return false

    #asLines = @studiesBody.split( /\n/ )
    # bDidFirstLine = false
    CSV.parse( @studiesBody, headers: true ) do |row|
      # use row here...
      #logger.info( "parseStudies: row: #{row}" )
      # if !bDidFirstLine
        # logger.info( "parseStudies: first row: #{row}" )
      # logger.info( "parseStudies: first row.inspect: #{row.inspect}" )
        # bDidFirstLine = true
      # else
      # end
      logger.debug( "parseStudies: row.id: #{row[ KStudyKeyID ]}" )
      @studiesParsed[ row[ KStudyKeyID ]]  = row
    end

    logger.info( "parseStudies: studiesParsed.length: #{@studiesParsed.length}" )
    return true
    # CSV.foreach( data_file, headers: true) do |row|
    #   puts row.inspect # hash
    # end
  
    # keys = ['time', etc... ]
    # CSV.parse(test).map {|a| Hash[ keys.zip(a) ] }
    # asLines = @attributesBody.split( /\n/ )
    # parseState  = KParseStateNone
    # entityType  = KEntityTypeNone

    # asLines.each do |oneLine|
    #   #logger.info( "parseState: #{parseState}  oneLine: #{oneLine}")

    #   case parseState
    #   when KParseStateNone
    #     # Looking for Output "entity-type"
    #     if oneLine.start_with?( KLinePrefixEntityType )
    #       # entity-type=study
    #       asPair  = oneLine.split( "=" )
    #       if 2 != asPair.length()
    #         logger.error( "parseAttributes: MALFORMED asPair=#{asPair}" )
    #       end

    #       parseState  = KParseStateEntityType
    #       entityType  = asPair[1]
    #       logger.info( "parseState: #{parseState}  entityType=#{entityType}")
    #     # else
    #     #   logger.info( "parseState: #{parseState}  dump and continue: #{oneLine}")
    #     end

    #   when KParseStateEntityType
    #     # We saw the entity-type line, now looking for "Output attributes"
    #     if oneLine.start_with?( KLinePrefixOutputAttrs )
    #       attrsString = oneLine[ KLinePrefixOutputAttrs.length..-1 ]
    #       attrsList   = attrsString.split( "," ).map( &:strip )
    #       #logger.info( "KLinePrefixOutputAttrs - attrsList: #{attrsList}")
    #       @attributesParsed[ entityType ] = { KKeyOutputAttributes => attrsList }
    #       parseState  = KParseStateOutputAttributes
    #     else
    #       logger.error( "parseAttributes: expecting Output attributes, UNEXPECTED oneLine=#{oneLine}" )
    #       parseState  = KParseStateNone
    #     end

    #   when KParseStateOutputAttributes
    #     # We saw the Output Attributes line, now looking for "Filter attributes"
    #     if oneLine.start_with?( KLinePrefixFilterAttrs )
    #       attrsString = oneLine[ KLinePrefixFilterAttrs.length..-1 ]
    #       attrsList   = attrsString.split( "," ).map( &:strip )
    #       #logger.info( "KLinePrefixFilterAttrs - attrsList: #{attrsList}")
    #       @attributesParsed[ entityType ][ KKeyFilterAttributes ] = attrsList
    #       parseState  = KParseStateNone
    #     else
    #       logger.error( "parseAttributes: expecting Filter attributes, UNEXPECTED oneLine=#{oneLine}" )
    #       parseState  = KParseStateNone
    #     end

    #   end
    # end

    # return true
  end
end


# def another_hello
#   puts "Hello World (from a method)"
# end

# logger = Logger.new( STDOUT )
logger  = Logging.logger_for( "main" )
#logger.info( "main: hello" )
# logger.level = Logger::INFO

# c = MyClass.new
# c.say_hello
# another_hello

# myConfig  = { "movebank" => { "user" => "",
#                             "password" => "" }}
configFilePath  = ""

ARGV.each do |oneArg|
  asPair  = oneArg.split("=")
  if 2 != asPair.length()
    logger.error( "MALFORMED oneArg: #{oneArg}" )
    logger.error( "      all arguments should be \"key=value\"" )
  else
    # logger.info( "main: oneArg: #{oneArg}" )
    # if asPair[0] == "u"
    #   myConfig[ "movebank" ][ "user" ]  = asPair[1]
    # elsif asPair[0] == "p"
    #   myConfig[ "movebank" ][ "password" ]  = asPair[1]
    if asPair[0] == "config"
      configFilePath  = asPair[1]
    else
      logger.error( "UNKNOWN oneArg: #{oneArg}" )
    end
  end
end

#logger.info( "myConfig: #{myConfig}" )
# myConfig  = ParseConfig.new( configFilePath )
# user = config.get_value(‘user’)
# pass = config.get_value(‘pass’)
# log_file = config.get_value(‘log_file’)
logger.info( "load config from configFilePath=#{configFilePath}" )
Config.load_and_set_settings( configFilePath )
logger.info( "Settings.username: #{Settings.username}" )
logger.info( "Settings.password: #{Settings.password}" )
logger.info( "Settings.functions.attributes: #{Settings.functions.attributes}" )


#mvbank  = MovebankAPI.new( myConfig[ "movebank" ][ "user" ], myConfig[ "movebank" ][ "password" ])
mvbank  = MovebankAPI.new( Settings.username, Settings.password )

if 0 != Settings.functions.attributes
  # Get a list of attribute names
  # https://www.movebank.org/movebank/service/direct-read?attributes
  if mvbank.ReadAttributes()
    mvbank.PrintAttributes()
  else
    logger.info( "mvbank.ReadAttributes: FAILED" )
  end
end

# You can obtain information about the following entity types in the database prior to specifying a specific study:
# study, tag_type, taxon.
if 0 != Settings.functions.studies
    if mvbank.ReadStudies()
    mvbank.PrintStudies( "whale" )
    mvbank.PrintStudies( "shark" )
  else
    logger.info( "mvbank.ReadStudies: FAILED" )
  end
end

if 0 != Settings.functions.tagtypes
    if mvbank.ReadTagTypes()
    mvbank.PrintTagTypes()
  else
    logger.info( "mvbank.ReadTagTypes: FAILED" )
  end
end

if 0 != Settings.functions.taxonomies
  if mvbank.ReadTaxonomies()
    mvbank.PrintTaxonomies()
  else
    logger.info( "mvbank.ReadTaxonomies: FAILED" )
  end
end
