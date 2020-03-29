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

    # For TagTypes
    # description,external_id,id,is_location_sensor,name
    KTagTypeKeyID = "id"
    KTagTypeKeyIsLocationSensor = "is_location_sensor"
    KTagTypeKeyName             = "name"

    # For Taxonomies
    # author_string,canonical_name,external_id,hierarchy_string,id,name_1,name_2,name_3,tsn,valid
    # "(Bleeker, 1864)","Canthigaster amboinensis",,"16762-261312088-261312089-817-18489-261312092-2031-2066-5385-10055-10160-10161-774077540-10187-10189",10189,"Canthigaster","amboinensis","",173321,true
    KTaxonomyKeyID  = "id"
    KTaxonomnyKeyCanonicalName  = "canonical_name"


    def initialize( usernameIn, passwordIn )
      @mvbUsername    = usernameIn
      @mvbPassword    = passwordIn
      @attributesBody = ""
      @attributesParsed = nil
      @studiesBody    = ""
      @studiesParsed  = nil
      @tagTypesBody   = ""
      @tagTypesParsed = nil
      @taxonomiesBody   = ""
      @taxonomiesParsed = nil
    end


    def ReadAttributes
      # curl -v -u dlevers:stANley6 -b cookies.txt -o attribute_names.txt "https://www.movebank.org/movebank/service/direct-read?attributes"
      resRequest  = submitRequest( "https://www.movebank.org/movebank/service/direct-read?attributes" )
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


    def ReadTagTypes
      # Get a list of sensor types
      resRequest  = submitRequest( "https://www.movebank.org/movebank/service/direct-read?entity_type=tag_type" )
      if resRequest.kind_of?( Net::HTTPSuccess )
        @tagTypesBody = resRequest.body
        #logger.info( "ReadTagTypes: tagTypesBody: #{@tagTypesBody}")
        if !parseTagTypes()
          logger.error( "ReadTagTypes: parseTagTypes FAILED" )
        end
        return true
      end

      return false
    end


    def ReadTaxonomies
      resRequest  = submitRequest( "https://www.movebank.org/movebank/service/direct-read?entity_type=taxon" )
      if resRequest.kind_of?( Net::HTTPSuccess )
        @taxonomiesBody = resRequest.body
        #logger.info( "ReadTaxonomies: taxonomiesBody: #{@taxonomiesBody}")
        if !parseTaxonomies()
          logger.error( "ReadTaxonomies: parseTaxonomies FAILED" )
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


    def PrintTagTypes()
      if !@tagTypesParsed
        if !parseTagTypes()
          logger.error( "PrintTagTypes: parseTagTypes FAILED" )
        end
      end

      @tagTypesParsed.each_value do |oneTagType|
        logger.info( "PrintTagTypes: id=#{oneTagType.field( KTagTypeKeyID )}  is_location_sensor: #{oneTagType.field( KTagTypeKeyIsLocationSensor )}  name: #{oneTagType.field( KTagTypeKeyName )}" )
      end
    end


    def PrintTaxonomies( descFilterIn )
      if !@taxonomiesParsed
        if !parseTaxonomies()
          logger.error( "PrintTaxonomies: parseTaxonomies FAILED" )
        end
      end

      @taxonomiesParsed.each_value do |oneTaxonomy|
        offset  = oneTaxonomy.field( KTaxonomnyKeyCanonicalName ).match( /#{descFilterIn}/i )
        if offset
          logger.info( "PrintTaxonomies: matching #{descFilterIn}  id=#{oneTaxonomy.field( KTaxonomyKeyID )}  canonical: #{oneTaxonomy.field( KTaxonomnyKeyCanonicalName )}" )
        end
      end
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
          end

        when KParseStateEntityType
          # We saw the entity-type line, now looking for "Output attributes"
          if oneLine.start_with?( KLinePrefixOutputAttrs )
            attrsString = oneLine[ KLinePrefixOutputAttrs.length..-1 ]
            attrsList   = attrsString.split( "," ).map( &:strip )
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

      CSV.parse( @studiesBody, headers: true ) do |row|
        logger.debug( "parseStudies: row.id: #{row[ KStudyKeyID ]}" )
        @studiesParsed[ row[ KStudyKeyID ]]  = row
      end

      logger.info( "parseStudies: studiesParsed.length: #{@studiesParsed.length}" )
      return true
    end


    def parseTagTypes
      if !@tagTypesBody
        @tagTypesParsed = nil
        return false
      end

      @tagTypesParsed = {}

      CSV.parse( @tagTypesBody, headers: true ) do |row|
        logger.debug( "parseTagTypes: row.id: #{row[ KTagTypeKeyID ]}" )
        @tagTypesParsed[ row[ KTagTypeKeyID ]]  = row
      end

      logger.info( "parseTagTypes: tagTypesParsed.length: #{@tagTypesParsed.length}" )
      return true
    end


    def parseTaxonomies
      if !@taxonomiesBody
        @taxonomiesParsed = nil
        return false
      end

      @taxonomiesParsed = {}

      CSV.parse( @taxonomiesBody, headers: true ) do |row|
        logger.debug( "parseTaxonomies: row.id: #{row[ KTaxonomyKeyID ]}" )
        @taxonomiesParsed[ row[ KTaxonomyKeyID ]]  = row
      end

      logger.info( "parseTaxonomies: taxonomiesParsed.length: #{@taxonomiesParsed.length}" )
      return true
    end
end
