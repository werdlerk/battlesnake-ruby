require "spec_helper"

RSpec.describe "BattleSnake" do
  def app
    BattleSnake
  end

  context "root" do
    it "returns basic configuration" do
      get "/"

      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).to include(
        {
          "apiversion" => "1",
          "author" => "koen",
        }
      )
    end
  end

  context "pathfinding" do
    it "returns the next move" do
      params = File.read("./spec/app/params.json")
      post "/move", params, 'CONTENT_TYPE' => 'application/json'

      expect(JSON.parse(last_response.body)).to include({"move" => "right"})
    end

    context "without a possible path" do
      it "returns the best next possible move" do
        params = File.read("./spec/app/params_without_path.json")
        post "/move", params, 'CONTENT_TYPE' => 'application/json'

        expect(JSON.parse(last_response.body)).to include({"move" => "up"})
      end
    end
  end

  context "wrapped field" do
    it "allows moving outside of board" do
      params = File.read("./spec/app/params_wrap_to_other_side.json")
      post "/move", params, 'CONTENT_TYPE' => 'application/json'

      expect(JSON.parse(last_response.body)).to include({"move" => "up"})
    end
  end

  context "test" do

    it "works" do
      params = File.read("./spec/app/params_solo_standard.json")
      post "/move", params, 'CONTENT_TYPE' => 'application/json'

      expect(JSON.parse(last_response.body)).to include({"move" => "up"})
    end
  end
end
