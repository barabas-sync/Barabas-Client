/**
    This file is part of Barabas Client Library.

	Copyright (C) 2011 Nathan Samson
 
    Barabas Client Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas Client Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Barabas Client Library.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.Client
{
	public class VersionCommitCommand : ICommand
	{

		private SyncedFileVersion version_to_sync;
		private int64 commit_id;
	
		public override string command_type { get { return "commitVersion"; } }

		public VersionCommitCommand (SyncedFileVersion file_version, 
		                             int64 commit_id)
		{
			this.version_to_sync = file_version;
			this.commit_id = commit_id;
		}

		public override Json.Generator? execute ()
		{
			Json.Generator gen;
			var commit_version = json_message(out gen);
		
			commit_version.set_string_member("request", command_type);
			commit_version.set_int_member("commit-id", commit_id);
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{
			// TODO: add failure detection
			// Normally all is wel...
		
			version_to_sync.set_remote(response.get_int_member("version-id"));
			version_to_sync.upload_stopped();
		}
	}
}
