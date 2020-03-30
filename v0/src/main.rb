require 'csv'
require 'config'
#require 'json'
#require 'net/http'

require_relative "mylogging"
require_relative "movebank_api"


##############################################################################
# main start
##############################################################################

logger  = Logging.logger_for( "main" )

configFilePath  = ""

ARGV.each do |oneArg|
  asPair  = oneArg.split("=")
  if 2 != asPair.length()
    logger.error( "MALFORMED oneArg: #{oneArg}" )
    logger.error( "      all arguments should be \"key=value\"" )
  else
    if asPair[0] == "config"
      configFilePath  = asPair[1]
    else
      logger.error( "UNKNOWN oneArg: #{oneArg}" )
    end
  end
end

logger.info( "load config from configFilePath=#{configFilePath}" )
Config.load_and_set_settings( configFilePath )
logger.info( "Settings.username: #{Settings.username}" )
logger.info( "Settings.password: #{Settings.password}" )
logger.info( "Settings.functions.attributes: #{Settings.functions.attributes}" )
logger.info( "Settings.functions.studies:    #{Settings.functions.studies}" )
logger.info( "Settings.functions.tagtypes:   #{Settings.functions.tagtypes}" )
logger.info( "Settings.functions.taxonomies: #{Settings.functions.taxonomies}" )
logger.info( "Settings.study.id: #{Settings.study.id}" )


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
    mvbank.PrintTaxonomies( "florida" )
  else
    logger.info( "mvbank.ReadTaxonomies: FAILED" )
  end
end

if mvbank.ReadStudy( Settings.study.id )
  mvbank.PrintStudy( Settings.study.id )
else
  logger.info( "mvbank.ReadStudy: FAILED" )
end
