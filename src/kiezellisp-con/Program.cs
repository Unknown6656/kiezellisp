﻿#region Header

// Copyright (C) Jan Tolenaar. See the file LICENSE for details.

#endregion Header

namespace Kiezel
{
    using System;
    using System.Globalization;
    using System.Threading;

    class Program
    {
        #region Private Methods

        [STAThread]
        static void Main(string[] args)
        {
            RuntimeConsoleBase.ResetRuntimeFunctionImp = RuntimeConsole.Reset;
            RuntimeConsoleBase.ResetDisplayFunctionImp = RuntimeConsole.ReplResetDisplay;
            RuntimeConsoleBase.ReadFunctionImp = RuntimeConsole.ReplRead;

            Thread.CurrentThread.CurrentCulture = CultureInfo.InvariantCulture;

            var options = RuntimeConsole.ParseArgs(args);

            RuntimeConsole.RunConsoleMode(options);
        }

        #endregion Private Methods
    }

    public partial class RuntimeConsole
    {
        #region Public Methods

        public static void Reset(int level)
        {
            Runtime.Reset();
            Runtime.RestartBuiltins(typeof(RuntimeConsole));
            Symbols.StdScr.ConstantValue = null;
            Symbols.StdErr.VariableValue = Console.Out;
            Symbols.StdLog.VariableValue = Console.Out;
            Symbols.StdOut.VariableValue = Console.Out;
            Symbols.StdIn.VariableValue = Console.In;
            Runtime.RestartLoadFiles(level);
        }

        #endregion Public Methods
    }
}