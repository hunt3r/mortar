#
# Copyright 2012 Mortar Data Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Mortar
	module PigVersion
		PIG_0_9_TGZ_NAME = "pig-0.9.tar.gz"
  		PIG_0_9_TGZ_DEFAULT_URL_PATH = "resource/pig_0_9"
  		PIG_0_12_TGZ_NAME = "pig-0.12.tar.gz"
  		PIG_0_12_TGZ_DEFAULT_URL_PATH = "resource/pig_0_12"

  		def PigVersion.from_string(pig_version_str)
  			if pig_version_str == '0.9'
  				return Pig09.new
  			elsif pig_version_str == '0.12'
  				return Pig012.new
  			else
  				raise ArgumentError, "Unsupported pig version: #{pig_version_str}"
  			end
  		end

		class Pig09
			def tgz_name
				PIG_0_9_TGZ_NAME
			end

			def tgz_default_url_path
				PIG_0_9_TGZ_DEFAULT_URL_PATH
			end

			def name
				"pig-#{version}"
			end

			def version
				"0.9"
			end
		end

		class Pig012
			def tgz_name
				PIG_0_12_TGZ_NAME
			end

			def tgz_default_url_path
				PIG_0_12_TGZ_DEFAULT_URL_PATH
			end

			def name
				"pig-#{version}"
			end

			def version
				"0.12"
			end
		end

	end
end