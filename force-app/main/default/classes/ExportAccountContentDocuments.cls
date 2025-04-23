global class ExportAccountContentDocuments {

    @AuraEnabled
    public static String generateCSV() {
        // Query Accounts and related ContentDocumentLinks and ContentDocuments
        List<Account> accounts = [
            SELECT Id, Name, 
                   (SELECT ContentDocument.Title, ContentDocument.Id, ContentDocument.FileExtension, ContentDocument.LatestPublishedVersion.Attachment_Type__c,
                    ContentDocument.LatestPublishedVersion.Status__c
                    FROM ContentDocumentLinks)
            FROM Account
            WHERE Id IN (SELECT LinkedEntityId FROM ContentDocumentLink)
        ];

        // Create a CSV header
        String csv = 'Account Id,Account Name,Document Id,Document Title,Document Type, Status\n';

        // Populate CSV rows
        for (Account account : accounts) {
            for (ContentDocumentLink docLink : account.ContentDocumentLinks) {
                ContentDocument doc = docLink.ContentDocument;
                if(doc.LatestPublishedVersion.Attachment_Type__c == 'Payment Agreement'){
                    csv += account.Id + ',' +
                       '"' + account.Name + '",' +
                       doc.Id + ',' +
                       '"' + doc.Title + '",' +
                    '"' + doc.LatestPublishedVersion.Attachment_Type__c+ '",' +
                       doc.LatestPublishedVersion.Status__c + '\n';
                }
            }
        }

        return csv;
    }

    @AuraEnabled
    public static void downloadCSV() {
        String csvContent = generateCSV();

        // Create a ContentVersion record to enable the file download
        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = 'AccountContentDocuments.csv';
        contentVersion.PathOnClient = 'AccountContentDocuments.csv';
        contentVersion.VersionData = Blob.valueOf(csvContent);
        insert contentVersion;
		
        System.debug('contentVersion: '+ contentVersion.Id);
        System.debug('ContentDocumentId: '+ contentVersion.ContentDocumentId);
        // Get the Id of the created ContentDocument
        
    }
}