#region Header

// Copyright (C) Jan Tolenaar. See the file LICENSE for details.

#endregion Header

namespace Kiezel
{
    using System;
    using System.Collections;
    using System.Collections.Generic;

    public class EnumeratorProxy : IEnumerator
    {
        #region Fields

        public IEnumerator Iter;

        #endregion Fields

        #region Constructors

        public EnumeratorProxy(IEnumerator iter)
        {
            Iter = iter;
        }

        #endregion Constructors

        #region Public Properties

        public object Current
        {
            get
            {
                return Iter.Current;
            }
        }

        #endregion Public Properties

        #region Public Methods

        public bool MoveNext()
        {
            return Iter.MoveNext();
        }

        public void Reset()
        {
            Iter.Reset();
        }

        #endregion Public Methods
    }

    public class UnisonEnumerator : IEnumerable<Vector>
    {
        #region Fields

        private IEnumerable[] sequences;

        #endregion Fields

        #region Constructors

        public UnisonEnumerator(IEnumerable[] sequences)
        {
            this.sequences = sequences ?? new IEnumerable[0];
        }

        #endregion Constructors

        #region Private Methods

        IEnumerator IEnumerable.GetEnumerator()
        {
            throw new NotImplementedException();
        }

        IEnumerator<Vector> IEnumerable<Vector>.GetEnumerator()
        {
            var iterators = new List<IEnumerator>();

            foreach (object seq in sequences)
            {
                if (seq is IEnumerable)
                {
                    iterators.Add(((IEnumerable)seq).GetEnumerator());
                }
                else {
                    iterators.Add(null);
                }
            }

            while (true)
            {
                var data = new Vector();
                var count = 0;

                for (var i = 0; i < iterators.Count; ++i)
                {
                    if (iterators[i] == null)
                    {
                        break;
                    }
                    else if (iterators[i].MoveNext())
                    {
                        ++count;
                        data.Add(iterators[i].Current);
                    }
                    else {
                        break;
                    }
                }

                if (count != 0 && count == iterators.Count)
                {
                    // full set
                    yield return data;
                }
                else {
                    break;
                }
            }
        }

        #endregion Private Methods
    }
}