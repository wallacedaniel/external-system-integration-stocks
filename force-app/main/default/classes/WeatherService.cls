public class WeatherService {
    private static final String WEATHER_API_TYPE = 'Weather_API';
    
    public class WeatherData {
        @AuraEnabled
        public Decimal temperature;
        @AuraEnabled
        public String condition;
        @AuraEnabled
        public Decimal humidity;
        @AuraEnabled
        public Decimal windSpeed;
    }
    
    public static WeatherData getWeatherForLocation(Id officeLocationId) {
        Office_Location__c location = [SELECT Latitude__c, Longitude__c FROM Office_Location__c WHERE Id = :officeLocationId LIMIT 1];
        
        if (location == null) {
            throw new WeatherServiceException('Office location not found');
        }
        
        // Get API configuration
        API_Configuration__mdt apiConfig = [SELECT Base_URL__c, API_Key__c, Timeout__c 
                                           FROM API_Configuration__mdt 
                                           WHERE API_Type__c = :WEATHER_API_TYPE 
                                           LIMIT 1];
        
        if (apiConfig == null) {
            throw new WeatherServiceException('Weather API configuration not found');
        }
        
        // Construct API URL
        String url = apiConfig.Base_URL__c + 
                     '?lat=' + String.valueOf(location.Latitude__c) + 
                     '&lon=' + String.valueOf(location.Longitude__c) + 
                     '&appid=' + apiConfig.API_Key__c;
        
        try {
            // Make HTTP callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod('GET');
            req.setTimeout(Integer.valueOf(apiConfig.Timeout__c));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse response
                Map<String, Object> weatherJson = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                WeatherData data = new WeatherData();
                data.temperature = (Decimal)weatherJson.get('main').get('temp');
                data.condition = (String)weatherJson.get('weather')[0].get('description');
                data.humidity = (Decimal)weatherJson.get('main').get('humidity');
                data.windSpeed = (Decimal)weatherJson.get('wind').get('speed');
                
                // Save to Weather_Data__c
                Weather_Data__c weatherRecord = new Weather_Data__c(
                    Office_Location__c = officeLocationId,
                    Temperature__c = data.temperature,
                    Weather_Condition__c = data.condition,
                    Humidity__c = data.humidity,
                    Wind_Speed__c = data.windSpeed,
                    Last_Updated__c = System.now(),
                    Weather_Date__c = System.today()
                );
                
                // Check for extreme weather conditions
                if (data.temperature > 100 || data.temperature < 0 || data.windSpeed > 50) {
                    weatherRecord.Is_Extreme_Weather__c = true;
                }
                
                insert weatherRecord;
                
                return data;
            } else {
                throw new WeatherServiceException('Weather API returned error: ' + res.getBody());
            }
        } catch (Exception e) {
            // Log error
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = WEATHER_API_TYPE,
                Status__c = 'Error',
                Request__c = url,
                Response__c = e.getMessage(),
                Error_Message__c = e.getMessage()
            );
            insert log;
            throw new WeatherServiceException('Failed to get weather data: ' + e.getMessage());
        }
    }
    
    public class WeatherServiceException extends Exception {}
}
