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
	public class VersionRequestCommand : ICommand
	{

		private SyncedFileVersion version_to_sync;
		private SyncedFile file_to_sync;
		private LocalFile local_file_to_upload;
		private string connection_host;
	
		public override string command_type { get { return "requestVersion"; } }

		public VersionRequestCommand (LocalFile local_file,
		                              SyncedFile file_to_sync,
		                              SyncedFileVersion version_to_sync,
		                              string connection_host)
		{
			this.local_file_to_upload = local_file;
			this.version_to_sync = version_to_sync;
			this.file_to_sync = file_to_sync;
			this.connection_host = connection_host;
		}

		public override Json.Generator? execute ()
		{
			if (version_to_sync.is_deprecated())
			{
				stdout.printf("Not uploading, newer version arrived.");
				return null;
			}
			Json.Generator gen;
			var version_request = json_message(out gen);
		
			version_request.set_string_member("request", command_type);
			version_request.set_int_member("file-id", file_to_sync.remoteID);
			version_request.set_string_member("version-name", version_to_sync.name);
			version_request.set_string_member("datetime-edited", to_barabas_date(version_to_sync.datetimeEdited));
		
			// TODO: add different methods negotation (plain, rsync, ...)
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{	
			/**
			 TODO: limit the number of uploads
			**/
			
			
			
			upload.begin(response);
		}
	
		private async void upload (Json.Object response)
		{
			// Wait for 2 seconds. It maybe possible that other versions come up.
			Timeout.add_seconds(2, upload.callback);
			yield;

			if (version_to_sync.is_deprecated())
			{
				stdout.printf("Upload canceled\n");
				canceled();
				return;
			}

			int64 commit_id = response.get_int_member("commit-id");
			Json.Object channel_info = response.get_object_member("channel-info");
			int64 port = channel_info.get_int_member("port");
			string host = channel_info.get_string_member("host");
			string secret = channel_info.get_string_member("secret");
			if (host == null)
			{
				host = connection_host;
			}
	
			var socket = new GLib.SocketClient();
			
			GLib.SocketConnection connection = null;
			int connect_tries = 0;
			while (connection == null)
			{
				try
				{
					connection = yield socket.connect_to_host_async(host, (uint16)port);
				}
				catch (GLib.IOError iO_connect_error)
				{
					stdout.printf("Connection error.\n");
					connect_tries++;
					GLib.Timeout.add(200, upload.callback);
					yield;
				}
				catch (GLib.Error connect_error)
				{
					// TODO: catch error
				}
			}
		
			try
			{
				if (version_to_sync.is_deprecated())
				{
					stdout.printf("Upload canceled\n");
					canceled();
					return;
				}
			
				yield connection.output_stream.write_async(secret.data);
			
				version_to_sync.upload_started();
		
				GLib.File file = GLib.File.new_for_uri(local_file_to_upload.uri);
				GLib.FileInfo info = yield file.query_info_async(GLib.FILE_ATTRIBUTE_STANDARD_SIZE, GLib.FileQueryInfoFlags.NONE);
				GLib.FileIOStream stream = yield file.open_readwrite_async();
		
				ssize_t total_read = 0;
				int64 total_to_read = info.get_size();
				uint8[] buffer = new uint8[2048];
				GLib.log("network", LogLevelFlags.LEVEL_INFO, "Uploading");
				while (total_to_read > total_read)
				{
					ssize_t current_stride = yield stream.input_stream.read_async(buffer);
					buffer.resize((int)current_stride);
					total_read += current_stride;
					yield connection.output_stream.write_async(buffer);
					version_to_sync.upload_progressed((int64)total_read, total_to_read);
				
					GLib.Timeout.add(50, upload.callback);
					yield;
				}
		
				connection.close();
				local_file_to_upload.update_last_modification_time();
			
				success(version_to_sync, commit_id);
			}
			catch (GLib.IOError io_error)
			{
				// TODO: more errors
			}
			catch (GLib.Error error)
			{
				// TODO: errors
			}
		}
	
		public signal void canceled();
		public signal void success(SyncedFileVersion file_version, int64 commit_id);
	}
}
