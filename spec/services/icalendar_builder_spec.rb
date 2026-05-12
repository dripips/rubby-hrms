require "rails_helper"

RSpec.describe IcalendarBuilder do
  let(:start_at) { Time.zone.parse("2026-06-01 10:00:00") }
  let(:end_at)   { Time.zone.parse("2026-06-01 11:00:00") }

  def add_minimal(builder, **overrides)
    builder.add_event(
      uid:      "test-1@hrms",
      summary:  "Tech Interview",
      start_at: start_at,
      end_at:   end_at,
      **overrides
    )
  end

  describe "#to_s" do
    let(:builder) { described_class.new(prod_id: "HRMS Test") }

    it "wraps output in BEGIN:VCALENDAR / END:VCALENDAR" do
      ics = add_minimal(builder).to_s
      expect(ics).to start_with("BEGIN:VCALENDAR\r\n")
      expect(ics).to end_with("END:VCALENDAR\r\n")
    end

    it "emits required calendar headers" do
      ics = add_minimal(builder).to_s
      expect(ics).to include("VERSION:2.0")
      expect(ics).to include("PRODID:-//HRMS Test//EN")
      expect(ics).to include("CALSCALE:GREGORIAN")
      expect(ics).to include("METHOD:PUBLISH")
    end

    it "emits VEVENT with UID/DTSTART/DTEND/SUMMARY/DTSTAMP" do
      ics = add_minimal(builder).to_s
      expect(ics).to include("BEGIN:VEVENT")
      expect(ics).to include("UID:test-1@hrms")
      expect(ics).to include("DTSTART:20260601T070000Z")  # 10:00 MSK → 07:00 UTC
      expect(ics).to include("DTEND:20260601T080000Z")
      expect(ics).to include("SUMMARY:Tech Interview")
      expect(ics).to match(/DTSTAMP:\d{8}T\d{6}Z/)
      expect(ics).to include("END:VEVENT")
    end

    it "uses CRLF line endings (RFC 5545 §3.1)" do
      ics = add_minimal(builder).to_s
      # каждая строка кроме последней пустой завершается \r\n
      lines = ics.split("\r\n")
      expect(lines).to include("BEGIN:VCALENDAR")
      expect(lines).to include("END:VCALENDAR")
    end

    it "supports multiple events in one calendar" do
      builder = described_class.new
      add_minimal(builder, uid: "a")
      add_minimal(builder, uid: "b")
      ics = builder.to_s
      expect(ics.scan("BEGIN:VEVENT").size).to eq(2)
      expect(ics).to include("UID:a")
      expect(ics).to include("UID:b")
    end
  end

  describe "TEXT escaping (RFC 5545 §3.3.11)" do
    let(:builder) { described_class.new }

    it "escapes comma" do
      ics = add_minimal(builder, summary: "Иван, Петров").to_s
      expect(ics).to include('SUMMARY:Иван\\, Петров')
    end

    it "escapes semicolon" do
      ics = add_minimal(builder, summary: "a;b").to_s
      expect(ics).to include('SUMMARY:a\\;b')
    end

    it "escapes newline" do
      ics = add_minimal(builder, description: "Line one\nLine two").to_s
      expect(ics).to include('DESCRIPTION:Line one\\nLine two')
    end

    it "escapes backslash" do
      ics = add_minimal(builder, summary: 'has\\backslash').to_s
      expect(ics).to include('SUMMARY:has\\\\backslash')
    end
  end

  describe "optional fields" do
    let(:builder) { described_class.new }

    it "omits DESCRIPTION when blank" do
      ics = add_minimal(builder).to_s
      expect(ics).not_to include("DESCRIPTION:")
    end

    it "emits DESCRIPTION / LOCATION / URL when present" do
      ics = add_minimal(builder,
                        description: "Tech round",
                        location: "Zoom",
                        url: "https://hrms.local/x").to_s
      expect(ics).to include("DESCRIPTION:Tech round")
      expect(ics).to include("LOCATION:Zoom")
      expect(ics).to include("URL:https://hrms.local/x")
    end
  end

  describe "line folding (RFC 5545 §3.1)" do
    it "folds lines longer than 75 octets with continuation space" do
      long_summary = "X" * 200
      builder = described_class.new
      add_minimal(builder, summary: long_summary)
      ics = builder.to_s

      # Find the SUMMARY line and check it's folded
      summary_line = ics.lines.detect { |l| l.start_with?("SUMMARY:") }
      expect(summary_line.bytesize).to be <= 77  # 75 + \r\n
      # Continuation lines start with space
      ics.lines.each do |line|
        next if line.start_with?("BEGIN", "END", "VERSION", "PRODID", "CALSCALE", "METHOD",
                                  "UID", "DTSTAMP", "DTSTART", "DTEND", "SUMMARY",
                                  "DESCRIPTION", "LOCATION", "URL")
        # if it's a continuation line, it starts with space
        # we don't enforce that all are continuations — just that *some* exist
      end
      # The full payload should still contain all 200 X's
      content = ics.gsub(/\r\n /, "")  # un-fold
      expect(content).to include("X" * 200)
    end
  end

  describe "UTC normalization" do
    it "converts local time to UTC zulu format" do
      builder = described_class.new
      # Moscow is +03:00 (no DST)
      add_minimal(builder, start_at: Time.zone.parse("2026-06-01 15:00"))
      ics = builder.to_s
      expect(ics).to include("DTSTART:20260601T120000Z")  # 15:00 MSK = 12:00 UTC
    end
  end
end
