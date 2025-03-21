@RestResource(urlMapping='/stocks/v1/*')
global with sharing class StockRestService {
    
    @HttpGet
    global static Map<String, Object> getStockHolding() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Extract holding ID from URL
            String holdingId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            
            // Validate the holding ID
            if(String.isBlank(holdingId) || !holdingId.startsWith('a0')) {
                res.statusCode = 400;
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'Invalid holding ID'
                };
            }
            
            // Get stock holding data
            Stock_Holding__c holding = [
                SELECT Id, Name, Company_Name__c, Quantity__c, Purchase_Price__c, 
                       Current_Price__c, Last_Updated__c, Client_Portfolio__r.Name
                FROM Stock_Holding__c
                WHERE Id = :holdingId
            ];
            
            // Calculate values
            Decimal marketValue = holding.Quantity__c * holding.Current_Price__c;
            Decimal profitLoss = (holding.Current_Price__c - holding.Purchase_Price__c) * holding.Quantity__c;
            Decimal changePercentage = (holding.Purchase_Price__c > 0) ? 
                                      ((holding.Current_Price__c - holding.Purchase_Price__c) / holding.Purchase_Price__c) * 100 : 0;
            
            // Return response
            return new Map<String, Object>{
                'success' => true,
                'portfolio' => new Map<String, Object>{
                    'id' => holding.Client_Portfolio__c,
                    'name' => holding.Client_Portfolio__r.Name
                },
                'stock' => new Map<String, Object>{
                    'id' => holding.Id,
                    'symbol' => holding.Name,
                    'companyName' => holding.Company_Name__c,
                    'quantity' => holding.Quantity__c,
                    'purchasePrice' => holding.Purchase_Price__c,
                    'currentPrice' => holding.Current_Price__c,
                    'marketValue' => marketValue,
                    'profitLoss' => profitLoss,
                    'changePercentage' => changePercentage,
                    'lastUpdated' => holding.Last_Updated__c
                }
            };
        } catch(Exception e) {
            // Log the error
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'Inbound',
                Status__c = 'Error',
                Request__c = 'GET ' + req.requestURI,
                Error_Message__c = e.getMessage(),
                Created_Date__c = Datetime.now()
            );
            insert log;
            
            // Return error response
            res.statusCode = 500;
            return new Map<String, Object>{
                'success' => false,
                'message' => 'An error occurred: ' + e.getMessage()
            };
        }
    }
    
    @HttpPost
    global static Map<String, Object> createStockHolding() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Log the request
            String requestBody = req.requestBody.toString();
            
            // Parse the request body
            Map<String, Object> requestData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            
            // Validate required fields
            if(!requestData.containsKey('portfolioId') || !requestData.containsKey('symbol') || 
               !requestData.containsKey('quantity') || !requestData.containsKey('purchasePrice')) {
                res.statusCode = 400;
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'Required fields missing: portfolioId, symbol, quantity, purchasePrice'
                };
            }
            
            // Create new stock holding
            Stock_Holding__c newHolding = new Stock_Holding__c(
                Client_Portfolio__c = (String)requestData.get('portfolioId'),
                Name = ((String)requestData.get('symbol')).toUpperCase(),
                Company_Name__c = (String)requestData.get('companyName'),
                Quantity__c = Double.valueOf(requestData.get('quantity')),
                Purchase_Price__c = Double.valueOf(requestData.get('purchasePrice')),
                Current_Price__c = Double.valueOf(requestData.get('purchasePrice')), // Initially set to purchase price
                Last_Updated__c = Datetime.now()
            );
            
            insert newHolding;
            
            // Log successful integration
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'Inbound',
                Status__c = 'Success',
                Request__c = 'POST ' + req.requestURI + ' ' + requestBody,
                Response__c = 'Created record: ' + newHolding.Id,
                Created_Date__c = Datetime.now()
            );
            insert log;
            
            // Return success response
            return new Map<String, Object>{
                'success' => true,
                'id' => newHolding.Id,
                'message' => 'Stock holding created successfully'
            };
        } catch(Exception e) {
            // Log the error
            Integration_Log__c log = new Integration_Log__c(
                Integration_Type__c = 'Inbound',
                Status__c = 'Error',
                Request__c = 'POST ' + req.requestURI + ' ' + req.requestBody.toString(),
                Error_Message__c = e.getMessage(),
                Created_Date__c = Datetime.now()
            );
            insert log;
            
            // Return error response
            res.statusCode = 500;
            return new Map<String, Object>{
                'success' => false,
                'message' => 'An error occurred: ' + e.getMessage()
            };
        }
    }
}