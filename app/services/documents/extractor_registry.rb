# Маппинг extractor_kind → класс. Centralized lookup для DocumentExtractionJob.
module Documents
  module ExtractorRegistry
    REGISTRY = {
      "passport" => PassportExtractor,
      "snils"    => SnilsExtractor,
      "inn"      => InnExtractor,
      "contract" => ContractExtractor,
      "diploma"  => DiplomaExtractor,
      "nda"      => NdaExtractor,
      "medical"  => MedicalExtractor
    }.freeze

    def self.for(kind)
      REGISTRY[kind.to_s]
    end

    def self.supported?(kind)
      REGISTRY.key?(kind.to_s)
    end

    def self.kinds
      REGISTRY.keys
    end
  end
end
