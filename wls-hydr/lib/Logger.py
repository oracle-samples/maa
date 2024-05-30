#!/usr/bin/python3

import logging
import os
import pathlib
import sys
import getpass


class Logger:
    """Logger object to write logging information to file and to console
    """
    def __init__(self, name, level):
        """Constructor

        Args:
            name (str): name of log file to write to
            level (str): log level ['DEBUG', 'INFO']
        """
        self.log_dir = pathlib.Path(__file__).parents[1].resolve().joinpath("log")
        self.calling_module = sys.argv[0].split("/")[-1]
        # check if log dir exists - it should - if not, create it
        if not os.path.isdir(self.log_dir):
            try:
                os.mkdir(self.log_dir)
            except OSError as e:
                print(f"ERROR: Could not create log directory:\n{str(e)}")
                sys.exit(1)
        self.logger = logging.getLogger(self.calling_module)
        if level == 'DEBUG':
            self.logger.setLevel(logging.DEBUG)
        else:
            self.logger.setLevel(logging.INFO)
        self.file_format = logging.Formatter(
            "%(asctime)s " + self.calling_module + " " + getpass.getuser() + " [%(levelname)s]: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S")
        self.log_file = pathlib.Path(self.log_dir).joinpath(name)
        self.log_file_handler = logging.FileHandler(self.log_file)
        # self.log_file_handler.setLevel(logging.DEBUG)
        self.log_file_handler.setFormatter(self.file_format)
        self.logger.addHandler(self.log_file_handler)

        # Configure console logging
        self.console_handler = logging.StreamHandler(sys.stdout)
        # self.console_handler.setLevel(self.logger.level)
        self.console_formatter = logging.Formatter('%(asctime)s [%(levelname)s]: %(message)s',
                                                   datefmt='%Y-%m-%d %H:%M:%S')
        self.console_handler.setFormatter(self.console_formatter)
        self.logger.addHandler(self.console_handler)


    def writelog(self, level, message):
        """Logger method that writes to file

        Args:
            level (str): level of log message
            message (str): mesage to be logged
        """
        if message:
            if level.lower() == 'critical':
                self.logger.critical(message)
            elif level.lower() == 'error':
                self.logger.error(message)
            elif level.lower() == 'warning':
                self.logger.warning(message)
            elif level.lower() == 'warn':
                self.logger.warning(message)
            elif level.lower() == 'info':
                self.logger.info(message)
            elif level.lower() == 'debug':
                self.logger.debug(message)
            else:
                self.logger.info('\n' + message)

if __name__ == '__main__':
    sys.exit(0)