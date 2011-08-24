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
	public errordomain ConnectionError
	{
		HOST_NOT_FOUND,
		UNKNOWN
	}
	
	public struct UserPasswordAuthentication
	{
		string username;
		string password;
		
		public UserPasswordAuthentication(string u, string p)
		{
			username = u;
			password = p;
		}
	}

	internal class MyStupidQueue<G> : GLib.Object, Gee.Iterable<G>, Gee.Collection<G>, Gee.Queue<G>
	{
		private Gee.ArrayList<G> list;
	
		public int capacity { get { return Gee.Queue.UNBOUNDED_CAPACITY; } }
		public int remaining_capacity { get { return Gee.Queue.UNBOUNDED_CAPACITY; } }
		public bool is_full { get { return false; } }
		
		public int size { get { return list.size; } }
		public bool is_empty { get { return list.is_empty; } }
		public Gee.Collection<G> read_only_view { owned get { return list.read_only_view; } }
	
		public MyStupidQueue()
		{
			list = new Gee.ArrayList<G>();
		}
		
		public Type element_type { get { return list.element_type; } }
		
		public bool contains (G g) { return list.contains(g); }
		public bool add (G g) { offer(g); return true; }
		public bool remove (G g) { return false; }
		public void clear () { list.clear(); }
		public bool add_all (Gee.Collection<G> g) { return false; }
		public bool contains_all (Gee.Collection<G> g) { return false; }
		public bool remove_all (Gee.Collection<G> g) { return false; }
		public bool retain_all (Gee.Collection<G> g) { return false; }
		public G[] to_array () { return list.to_array(); }
	
		public bool offer(G g)
		{
			list.insert(list.size, g);
			return true;
		}
		
		public G peek()
		{
			if (is_empty)
				return null;
			return list.first();
		}
		
		public G poll()
		{
			if (is_empty)
				return null;
			G g = list.first();
			list.remove_at(0);
			
			return g;
		}
		
		public int drain(Gee.Collection<G> recp, int amount = -1)
		{
			recp.add(poll());
			return 1;
		}
		
		public Gee.Iterator<G> iterator()
		{
			return list.iterator();
		}
	}

	public class Connection
	{
		private GLib.SocketClient socket;
		private GLib.SocketConnection connection;
		private GLib.IOChannel socketChannel;
		public ConnectionStatus connection_status { get; private set; }
		
		private Gee.List<string> enabled_authentication_methods;
		private string[] current_authentication_methods;
		
		private Database database;
		private UnsavedChangesCrawler unsaved_changes_crawler;
		
		private ICommand current_request;
		private Gee.Queue<ICommand> request_queue;
		
		private GLib.Cancellable connect_cancellable;
		
		public string connected_host { get; private set; }
		
		public delegate void SearchCompletes(string search, int[] result);
		public delegate void FileInfoRequest(FileInfo info);

		public Connection(Database database)
		{
			SyncedFile.cache.added.connect(on_added_synced_file);
			this.database = database;
			this.status_changed.connect((status, msg) => {
				this.connection_status = status;
				if (status == ConnectionStatus.CONNECTED)
				{
					stdout.printf("STATUS CHANGED");
					DownloadLogCommand command = new DownloadLogCommand(database);
					command.success.connect(on_finished_download_first_log);
					command.download_new_version.connect(on_download_new_version);
					queue_command(command);
					unsaved_changes_crawler.crawl.begin();
				} else {
					unsaved_changes_crawler.stop();
					request_queue.clear();
				}
			});
			enabled_authentication_methods = new Gee.LinkedList<string>();
		
			current_request = null;
			request_queue = new MyStupidQueue<ICommand> ();
			unsaved_changes_crawler = new UnsavedChangesCrawler(this, database);
		}
	
		public void enable_authentication_method(string method)
		{
			enabled_authentication_methods.add(method);
		}
	
		public async void connect(string hostname, uint16 port = 2188) throws ConnectionError
		{
			try
			{
				if (connection != null)
				{
					disconnect();
				}
			
				status_changed(ConnectionStatus.CONNECTING);
				socket = new GLib.SocketClient();
				connect_cancellable = new GLib.Cancellable();
				connection = yield socket.connect_to_host_async(hostname, port, connect_cancellable);
				connected_host = hostname;
				socketChannel = new GLib.IOChannel.unix_new(connection.socket.fd);
				socketChannel.add_watch(GLib.IOCondition.IN, data_received);
				
				string[] singleton_list = {};
				
				foreach (string method in enabled_authentication_methods)
				{
					if (method in singleton_list)
					{
						continue;
					}
					singleton_list += method;
				}
				
				HandshakeCommand handshake = new HandshakeCommand(singleton_list);
				handshake.success.connect(on_handshake_success);
				handshake.failure.connect(on_handshake_failure);
				current_request = handshake;
				send_message(handshake.execute());
			}
			catch (GLib.Error error)
			{
				if (error is GLib.IOError.CANCELLED)
				{
					status_changed(ConnectionStatus.NOT_CONNECTED, "");
				}
				else
				{
					status_changed(ConnectionStatus.DISCONNECTED, error.message);
				}
			}
		}
		
		public void connect_cancel()
		{
			connect_cancellable.cancel();
		}
		
		public void disconnect()
		{
			connected_host = "";
			socketChannel = null;
			connection.close();
			status_changed(ConnectionStatus.NOT_CONNECTED);
		}
		
		public void authenticate_user_password(UserPasswordAuthentication authentication)
		{
			status_changed(ConnectionStatus.AUTHENTICATING, "");
			UserPasswordLoginCommand login = new UserPasswordLoginCommand(authentication);
			login.authenticated.connect(() => {
				status_changed(ConnectionStatus.CONNECTED, "");
			});
			login.failure.connect((msg) => {
				status_changed(ConnectionStatus.AUTHENTICATION_FAILED, msg);
			});
			request_queue.offer(login);
			handle_next_request();
		}
		
		public void authenticate_cancel()
		{
			handle_next_authentication_method();
		}
		
		public signal void status_changed(ConnectionStatus status, string message = "");
		public signal void user_password_authentication_request();

		public void queue_command (ICommand command)
		{
			if (current_request != null || connection_status != ConnectionStatus.CONNECTED)
			{
				request_queue.offer (command);
			}
			else
			{
				current_request = command;
				Json.Generator? generator = command.execute();
				if (generator != null)
				{
					send_message(generator);
				}
			}
		}

		internal void sync_file(SyncedFile synced_file)
		{
			NewFileCommand command = new NewFileCommand(synced_file);
			command.success.connect((file_to_sync) => {
				file_to_sync.tagged.connect(on_tagged_file);
				file_to_sync.untagged.connect(on_untagged_file);
			});
			queue_command(command);
		}

		/* Watch the objects */
		
		private void on_added_synced_file(SyncedFile synced_file)
		{
			if (! synced_file.has_remote())
			{
				sync_file(synced_file);
			}
			else
			{
				synced_file.tagged.connect(on_tagged_file);
				synced_file.untagged.connect(on_untagged_file);
			}
		}
		
		private void on_tagged_file(SyncedFile synced_file, string tag, bool local)
		{
			if (local)
			{
				NewTagCommand command = new NewTagCommand(synced_file, tag);
				queue_command(command);
			}
		}
		
		private void on_untagged_file(SyncedFile synced_file, string tag, bool local)
		{
			if (local)
			{
				RemoveTagCommand command = new RemoveTagCommand(synced_file, tag);
				queue_command(command);
			}
		}
		
		private void on_finished_download_first_log()
		{
			GLib.Timeout.add_seconds(10, download_log);
		}
		
		private bool download_log()
		{
			if (connection_status != ConnectionStatus.CONNECTED)
			{
				return false;
			}
		
			DownloadLogCommand command = new DownloadLogCommand(database);
			command.download_new_version.connect(on_download_new_version);
			queue_command(command);
			return true;
		}
		
		private void on_download_new_version(SyncedFile synced_file,
		                                     SyncedFileVersion synced_file_version)
		{
			stdout.printf("ON DOWNLOAD NEW VERSION\n");
			LocalFile? local_file = LocalFile.from_file_id(synced_file.ID, database);
			if (local_file == null)
			{
				stdout.printf("NO LOCAL FILE\n");
				return;
			}
			
			RequestDownloadCommand request_download = new RequestDownloadCommand(synced_file_version,
			                                                                     local_file.uri,
			                                                                     connected_host);
			request_download.download_stopped.connect(() => {
				local_file.update_last_modification_time();
			});
			stdout.printf("QUEUE FOR DOWNLOAD\n");
			queue_command(request_download);
		}

		/* Network stuff */

		private void send_message(Json.Generator gen)
		{
			size_t length;
			var json_str = gen.to_data(out length);
			json_str += "\n";
			//GLib.log("protocol", LogLevelFlags.LEVEL_INFO, "Send message: %s", json_str);
			try
			{
				connection.output_stream.write(json_str.data);
			}
			catch (GLib.IOError error)
			{
				status_changed(ConnectionStatus.DISCONNECTED, error.message);
			}
		}

		private Json.Object parse_json_response(string msg) throws GLib.Error
		{
			var parser = new Json.Parser();
			parser.load_from_data(msg, -1);
			return parser.get_root().get_object();
		}
	
		private bool data_received(GLib.IOChannel source, GLib.IOCondition condition)
		{
			if (socketChannel == null)
			{
				// Someone reconnected.
				// This is on the old channel, and is probably a hangup
				// we should not do anything. Changing the status
				// will result in going from CONNECTING / AUTHENTICATING
				// to DISCONNECT which is not true.
				return false;
			}
		
			if (condition != GLib.IOCondition.IN && 
			    condition != GLib.IOCondition.OUT)
			{
				// We only listen to the IN condition, but observation
				// learnt that we sometimes receive other ones too.
				// These other ones are error conditions, so lets close the
				// connection.
				// TODO: think of a error message.
				status_changed(ConnectionStatus.DISCONNECTED, "");
			}

			string buffer;
			GLib.IOStatus read_status;
			try
			{
				size_t length;
				size_t terminater_pos;
				read_status = source.read_line(out buffer,
				                               out length,
				                               out terminater_pos);
			}
			catch (GLib.ConvertError error)
			{
				// Let's hope we just did not receive the \n yet.
				return true;
			}
			catch (GLib.IOChannelError error)
			{
				status_changed(ConnectionStatus.DISCONNECTED, error.message);
				return false;
			}
			if (read_status == GLib.IOStatus.NORMAL)
			{
				//GLib.log("protocol", LogLevelFlags.LEVEL_INFO, "Received message: %s", buffer);
				Json.Object message;
				try
				{
					message = parse_json_response(buffer);
				}
				catch (GLib.Error error)
				{
					// Server sent us a bogus command
					// Lets ignore and just pass on.
					stdout.printf("Received bogus message\n");
					return true;
				}
			
				if (message.has_member("request"))
				{
					string request = message.get_string_member("request");
					stdout.printf("Incoming request %s\n", request);
			
					return true;
				}
			
				string response = message.get_string_member("response");
				if (response == "error")
				{
					stdout.printf("Error: \n    code: %i\n    msg: %s\n",
						          (int)message.get_int_member("code"),
						          message.get_string_member("msg"));
				}
				else
				{
					// Search for current command, if found check type and pass on/
					if (current_request != null && 
					    current_request.command_type == response)
					{
						current_request.response (message);
					}
					else
					{
						// We received a bogus response from the server.
						// Just ignore
						return true;
					}
				}
				handle_next_request();
				return true;
			}
			else
			{
				// TODO: think of a error message.
				status_changed(ConnectionStatus.DISCONNECTED, "Unknown problem.");
				return false;
			}
		}
		
		private void on_handshake_success(string[] authentication_methods)
		{
			current_authentication_methods = authentication_methods;
			
			stdout.printf("SUCCESS\n");
			handle_next_authentication_method();
		}
		
		private void on_handshake_failure(string message)
		{
			status_changed(ConnectionStatus.DISCONNECTED, message);
		}
		
		private void handle_next_authentication_method()
		{
			if (current_authentication_methods.length < 1)
			{
				status_changed(ConnectionStatus.DISCONNECTED, "No authentication methods left.");
				return;
			}
			status_changed(ConnectionStatus.AUTHENTICATION_REQUEST, "");
			string method = current_authentication_methods[0];
			current_authentication_methods = current_authentication_methods[1:current_authentication_methods.length-1];
			
			if (method == "user-password")
			{
				user_password_authentication_request();
			}
		}
		
		private void handle_next_request()
		{
			Json.Generator? generator = null;
			do
			{
				generator = null;
				current_request = request_queue.poll();
				if (current_request != null)
					generator = current_request.execute();
			} while (generator == null && current_request != null);
			
			if (generator != null)
				send_message(generator);
		}
	}
}
