require "rails_helper"

RSpec.describe Documents::TextExtractor do
  describe ".call" do
    it "returns empty result for nil blob" do
      result = described_class.call(nil)
      expect(result[:text]).to eq("")
      expect(result[:method]).to eq("none")
      expect(result[:error]).to eq("no_blob")
    end

    it "returns empty result for blob without download method" do
      result = described_class.call(Object.new)
      expect(result[:error]).to eq("blob_not_attached")
    end

    it "returns unsupported_content_type for non-PDF/image blobs" do
      blob = double("Blob",
                    content_type: "application/zip",
                    download: "binary",
                    filename: double(to_s: "x.zip"))
      result = described_class.call(blob)
      expect(result[:method]).to eq("none")
      expect(result[:error]).to include("unsupported_content_type")
    end
  end

  describe "#poppler_available?" do
    before { described_class.poppler_available = nil }  # reset cache

    it "memoizes detection result on the class" do
      ext = described_class.new(nil)
      result1 = ext.send(:poppler_available?)
      expect(described_class.poppler_available).to eq(result1)
      # second call returns cached value, doesn't shell-out again
      expect(Open3).not_to receive(:capture3)
      result2 = ext.send(:poppler_available?)
      expect(result2).to eq(result1)
    end

    it "returns false when pdftoppm is not installed (Errno::ENOENT)" do
      described_class.poppler_available = nil
      allow(Open3).to receive(:capture3).with("pdftoppm", "-v").and_raise(Errno::ENOENT)
      expect(described_class.new(nil).send(:poppler_available?)).to be false
    end

    it "returns true when pdftoppm responds successfully" do
      described_class.poppler_available = nil
      status = double("ProcessStatus", success?: true, exitstatus: 0)
      allow(Open3).to receive(:capture3).with("pdftoppm", "-v").and_return([ "", "", status ])
      expect(described_class.new(nil).send(:poppler_available?)).to be true
    end
  end

  describe "#extract_from_image_pdf (scan-PDF path)" do
    before { described_class.poppler_available = false }  # simulate no poppler

    it "returns poppler_not_installed when binary missing" do
      ext = described_class.new(double(content_type: "application/pdf"))
      result = ext.send(:extract_from_image_pdf)
      expect(result[:error]).to eq("poppler_not_installed")
      expect(result[:method]).to eq("none")
    end
  end
end
