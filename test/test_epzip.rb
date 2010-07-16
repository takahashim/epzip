require 'helper'

class TestEpzip < Test::Unit::TestCase
  def test_zip_should_use_existed_dir
    assert_raise ArgumentError do
      Epzip.zip("unknown_dir")
    end
  end
end
