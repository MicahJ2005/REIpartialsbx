public with sharing class PropertyWareAPIUtility implements Schedulable, Database.AllowsCallouts{

    public void execute(SchedulableContext ctx) {
        getBuildings();
    }

    public static void getBuildings() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        Datetime now = Datetime.now(); // Current datetime
        // String toDateTime = now.addHours(-1).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 1 hour ago
        String fromDateTime = now.addHours(-24).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''); // 24 hours ago

        string dateTimeParameters = '?lastModifiedDateTimeStart='+ EncodingUtil.urlEncode(fromDateTime, 'UTF-8');
        System.debug(dateTimeParameters);

        request.setEndpoint('https://api.propertyware.com/pw/api/rest/v1/buildings'+ dateTimeParameters);
        request.setMethod('GET');

        // Set required headers
        request.setHeader('x-propertyware-client-id', '5654c21f-3490-49bb-9521-251b7e8d547c');
        request.setHeader('x-propertyware-client-secret', '57bb14b8-3659-4cc8-8f4e-dd778a7b3a66');
        request.setHeader('x-propertyware-system-id', '20348933');

        // Optional common headers
        request.setHeader('Accept', '*/*');
        request.setHeader('Accept-Encoding', 'gzip, deflate, br');
        request.setHeader('Connection', 'keep-alive');

        Map<String, PWBuildingWrapper> PWIdAndAddress = new Map<String, PWBuildingWrapper>();

        try {
            HttpResponse response = http.send(request);
            if(response.getStatusCode() == 200) {
                System.debug('Response body: ' + response.getBody());
                List<Object> raw = (List<Object>) JSON.deserializeUntyped(response.getBody());
                System.debug(raw);
                for(Object o: raw){
                    Map<String, Object> building = (Map<String, Object>) o;
                    System.debug(building);
                    PWBuildingWrapper bw = new PWBuildingWrapper();
                    for(String key: building.keySet()){
                        Address addressWrapper = new Address();
                        System.debug(key + ': ' + building.get(key));
                        if(key == 'address'){
                            System.debug('Address at 46: ' + building.get(key));
                            Map<String, Object> address = (Map<String, Object>) building.get(key);
                            System.debug(address);
                            
                            bw.address = String.valueOf(address.get('address'));
                            bw.city = String.valueOf(address.get('city'));  
                            bw.country = String.valueOf(address.get('country'));    
                            bw.stateRegion = String.valueOf(address.get('stateRegion'));
                            bw.postalCode = String.valueOf(address.get('postalCode'));
                            
                        }
                    }
                    bw.id = String.valueOf(building.get('id'));
                    bw.idNumber  = String.valueOf(building.get('idNumber'));
                    bw.portfolioID  = String.valueOf(building.get('portfolioID'));
                    
                    System.debug('id: '+ building.get('id'));
                    System.debug('idNumber: '+ building.get('idNumber'));
                    PWIdAndAddress.put(bw.id , bw);
                }
                // List<PWBuildingWrapper> PWBuildings = (List<PWBuildingWrapper>) JSON.deserialize(response.getBody(), List<PWBuildingWrapper>.class);
                // System.debug(PWBuildings);
                // List<Object> buildings = (List<Object>) responseMap.get('buildings');

                // System.debug(buildings);

            }
        } catch (Exception e) {
            System.debug('Callout error: ' + e.getMessage());
        }

        System.debug('PWIdAndAddress: '+ PWIdAndAddress);

        getPWBuildingByPWId(PWIdAndAddress);
    }
    
    public static void getPWBuildingByPWId(Map<String, PWBuildingWrapper> PWIdAndAddress){
        System.debug('PWIdAndAddress: '+ PWIdAndAddress);
        ////Need to Select buildings by PW Id
    }

    public static void syncBuildingsFromPW(List<PWBuilding> buildings) {
        for (PWBuilding building : buildings) {
            // Step 1: Ensure Portfolio Exists or Create It
            PW_Portfolio__c portfolio = getOrCreatePortfolio(building);

            // Step 2: Ensure House Exists or Create It
            House__c house = getOrCreateHouse(building);

            // Step 3: Check if PW Building exists
            PW_Building__c existingBuilding = getBuildingByEntityId(building.BuildingEntityId);
            if (existingBuilding == null) {
                PW_Building__c newBuilding = new PW_Building__c(
                    Name = building.Name,
                    PW_Status__c = building.Status,
                    PW_Active__c = building.Active,
                    PW_Building_Market__c = building.Market,
                    PW_Address__c = building.Address,
                    PW_City__c = building.City,
                    PW_State__c = building.State,
                    PW_Zip__c = building.Zip,
                    PW_Year_Built__c = building.YearBuilt,
                    PW_Bedrooms__c = building.Bedrooms,
                    PW_Bathrooms__c = building.Bathrooms,
                    PW_Building_Entity_ID__c = building.BuildingEntityId,
                    PW_Portfolio_Entity_ID__c = building.PortfolioEntityId,
                    PW_Building_ID_Number__c = building.BuildingIdNumber,
                    House__c = house.Id,
                    PW_Portfolio__c = portfolio.Id
                );
                insert newBuilding;
            }
        }
    }

    private static PW_Portfolio__c getOrCreatePortfolio(PWBuilding building) {
        List<PW_Portfolio__c> existing = [
            SELECT Id FROM PW_Portfolio__c WHERE PW_Portfolio_Entity_ID_Number__c = :building.PortfolioEntityId LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0];

        String orgName = (building.PWOrg == 'PPMG Texas') ? 'PPMG of Texas, LLC' : 'Premier Property Management Group';
        PW_Portfolio__c portfolio = new PW_Portfolio__c(
            Name = building.PortfolioName,
            PW_Portfolio_Entity_ID_Number__c = building.PortfolioEntityId,
            PW_Active__c = building.Active,
            PW_Org__c = orgName
        );
        insert portfolio;
        return portfolio;
    }

    private static House__c getOrCreateHouse(PWBuilding building) {
        String fullAddress = building.Address + ', ' + building.City + ', ' + building.State + ' ' + building.Zip;
        String placeId = GooglePlacesService.getPlaceIdFromAddress(fullAddress);

        List<House__c> existing = [
            SELECT Id FROM House__c WHERE Google_Place_ID__c = :placeId LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0];

        House__c house = new House__c(
            Market__c = building.Market,
            Name = building.Name,
            Street_Address__c = building.Address,
            City__c = building.City,
            State__c = building.State,
            Zip__c = building.Zip,
            House_Type__c = building.PropertyType,
            Bedrooms__c = building.Bedrooms,
            Bathrooms__c = building.Bathrooms,
            Car_Storage__c = null, // Set as needed
            Sq_Feet__c = building.TotalArea,
            Year_Built__c = building.YearBuilt,
            Status__c = 'Managed',
            Google_Place_ID__c = placeId
        );
        insert house;
        return house;
    }

    private static PW_Building__c getBuildingByEntityId(String entityId) {
        List<PW_Building__c> records = [
            SELECT Id FROM PW_Building__c WHERE PW_Building_Entity_ID__c = :entityId LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }


    public class PWBuildingWrapper {
        public String id;
        public String address;
        // public String addressCont;
        public String city;
        public String stateRegion;
        public String postalCode;
        public String country;
        // public String lastModifiedBy;
        // public Datetime lastModifiedDateTime;
        // public String createdBy;
        // public Datetime createdDateTime;
        public String idNumber;
        public String portfolioID;
        // public Integer leaseID;
        // public String name;
        // public String abbreviation;
        // public Address address;
        // public String type;
        // public String category;
        // public Integer floorNumber;
        // public Integer numberFloors;
        // public String neighborhood;
        // public Double totalArea;
        // public String areaUnits;
        // public String county;
        // public Boolean ready;
        // public Boolean active;
        // public Boolean rentable;
        // public Integer numberOfBedrooms;
        // public Double numberOfBathrooms;
        // public Double targetRent;
        // public String targetRentUnits;
        // public String searchTag;
        // public String targetDeposit;
        // public String status;
        // public String maintenanceNotice;
        // public List<String> amenities;
        // public String maintenanceSpendingLimitTime;
        // public Boolean syndicate;
        // public String website;
        // public String yearBuilt;
        // public Marketing marketing;
        // public List<PropertyManager> propertyManagerList;
        // public Management management;
        // public String multiUnit;
        // public Integer countUnit;
        // public String propertyType;
        // public Double maintenanceLaborSurchargeAmount;
        // public String maintenanceLaborSurchargeType;
        // public String ftbWithholdingType;
        // public Double ftbWithholdingPercentage;
        // public Double ftbDeductable;
        // public Double maintenanceSpendingLimitAmount;
        // public String reasonForPropertyLost;
        // public String applicationFeeRule;
    }
    public class Address {
        public String address;
        // public String addressCont;
        public String city;
        public String stateRegion;
        public String postalCode;
        public String country;
    }

    // public class Marketing {
    //     public String marketingName;
    //     public String availableDate;
    //     public String comments;
    //     public Boolean featured;
    //     public Boolean featuredForRent;
    //     public Boolean forSale;
    //     public Boolean publishedForSale;
    //     public Boolean featuredForSale;
    //     public String mlsLeaseNumber;
    //     public String mlsNumber;
    //     public String otherTenantCharges;
    //     public String parcelNumber;
    //     public Boolean petsAllowed;
    //     public String postingTitle;
    //     public Integer leaseTerms;
    //     public String leaseTermsUnits;
    //     public Double latitude;
    //     public Double longitude;
    //     public Double salePrice;
    //     public String saleTerms;
    //     public String shortDescription;
    //     public Boolean smokingAllowed;
    //     public String specials;
    //     public Boolean publishedForRent;
    //     public Boolean syndicate;
    //     public Integer moveInDays;
    // }

    // public class PropertyManager {
    //     public String id;
    //     public String roleAsString;
    //     public String userID;
    //     public String name;
    //     public String email;
    // }

    // public class Management {
    //     public String managementContractStartDate;
    //     public String managementContractEndDate;
    //     public Double managementFlatFee;
    //     public String managementFeeType;
    //     public String managementFeesType;
    //     public List<ManagementFee> managementFees;
    // }

    // public class ManagementFee {
    //     // public Long id;
    //     public Double percentage;
    //     public Boolean passThrough;
    //     public Double managersCommissionPercentage;
    //     public String manager;
    //     public String accountNumber;
    //     public String accountCode;
    // }
}