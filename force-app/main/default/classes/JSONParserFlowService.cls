public class JSONParserFlowService {

    public class InputWrapper {
        @InvocableVariable
        public String jsonInput;
    }

    public class OutputWrapper {
        @InvocableVariable
        public String jsonString;

        @InvocableVariable
        public String city;
    }

    @InvocableMethod(label='Parse JSON for Flow')
    public static void parseJson(List<InputWrapper> inputs) {
        system.debug('parseJson: '+inputs);
        // List<OutputWrapper> results = new List<OutputWrapper>();
        // for (InputWrapper input : inputs) {
        //     Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(input.jsonInput);
            
        //     OutputWrapper out = new OutputWrapper();
        //     out.name = (String) jsonMap.get('name');
        //     out.city = (String) jsonMap.get('city');
        //     results.add(out);
        // }
        // return results;
    }
}
