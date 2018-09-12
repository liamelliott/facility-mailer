require "visit"

describe Visit do

  FACILITY = Visit::Facility.new("CH", "Canmore Clubhouse").freeze

  # Construct minimum valid instance with only required keyword
  subject { Visit.new(facility: FACILITY) }

  describe ".initialize" do
    context "when initialization is successful" do
      it "accepts the correct keywords" do
        # Shitty workaround for rspec behavior with keyword exposure in :new with respond_to matcher
        expect(subject.method(:initialize).parameters).to eq([[:keyreq, :facility], [:key, :start_date], [:key, :number_of_nights]])
      end

      it "freezes the object" do
        expect(subject).to be_frozen
      end
    end

    context "when invalid facility is given" do
      it "fails to when an invalid facility is given" do
        expect { Visit.new(facility: nil) }.to raise_error(NoMethodError)
      end
    end
  end

  context "when object is minimal default instance" do
    it "responds to messages" do
      expect(subject).to respond_to(:facility)
      expect(subject).to respond_to(:start_date)
      expect(subject).to respond_to(:number_of_nights)
    end

    it "has a start_date equal to today" do
      expect(subject.start_date).to eq(Date.today)
    end

    it "has a number_of_nights equal to 1" do
      expect(subject.number_of_nights).to eq(1)
    end
  end

  describe "#end_date" do
    it "has the date of start_date plus the number of nights stayed" do
      expect(subject.end_date).to eq(subject.start_date + subject.number_of_nights)
    end
  end

  describe "#finished?" do
    context "when stay is not yet finished" do
      subject { Visit::new(facility: FACILITY, start_date: Date.today, number_of_nights: 5) }

      it "returns false" do
        expect(subject.finished?).to eq(false)
      end
    end

    context "when stay has finished" do
      subject { Visit::new(facility: FACILITY, start_date: Date.new(2018, 01, 01), number_of_nights: 5) }

      it "returns true" do
        expect(subject.finished?).to eq(true)
      end
    end
  end
end
