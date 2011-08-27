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
	public abstract class Cache<KEY, VALUE>
	{
		private Gee.Map<KEY, weak VALUE> mapping;
		
		public Cache()
		{
			mapping = new Gee.HashMap<KEY, weak VALUE>();
		}
		
		public bool has(KEY key)
		{
			return key in mapping.keys;
		}
		
		public VALUE? get(KEY key)
		{
			return mapping[key];
		}
		
		public void add(VALUE val)
		{
			mapping.set(key(val), val);
			a_added(val);
			((Object)val).weak_ref(deleting_object);
		}
		
		public void unset(KEY key)
		{
			mapping.unset(key);
		}
		
		private void deleting_object(Object object)
		{
			VALUE deleted = (VALUE)object;
			
			mapping.unset(key(deleted));
		}
		
		protected abstract void a_added(VALUE val);
		
		protected abstract KEY key(VALUE val);
	}
}
