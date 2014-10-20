import luigi
from luigi import configuration
from luigi.s3 import S3Target, S3PathTask

from mortar.luigi import mortartask

import logging

"""
Luigi is a powerful, easy-to-use framework for building data pipelines.

This is an example Luigi script to get you started. This script has a 
'fill in the blank' interaction. Feel free to alter it to build your pipeline.

In this example we will run a Pig script, and then shutdown any clusters associated
with that script.  We will do that by running the ShutdownClusters Task,
which is dependent on RunMyExamplePigScript Task. This means the cluster will only 
shutdown after RunMyExamplePigScript (where the data transformation happens) 
Task is completed.

For full tutorials and in-depth Luigi documentation, visit:
https://help.mortardata.com/technologies/luigi

To Run:
mortar luigi luigiscripts/<%= project_name %>_luigi.py \
    --output-base-path "s3://mortar-example-output-data/<your_username_here>/<%= project_name %>"
"""

MORTAR_PROJECT = '<%= project_name %>'

"""
This logger outputs logs to Mortar Logs. An example of it's usage can be seen
in the ShutdownClusters function.
"""
LOGGER = logging.getLogger('luigi-interface')

# helper function
def create_full_path(base_path, sub_path):
    return '%s/%s' % (base_path, sub_path)

class RunMyExamplePigScript(mortartask.MortarProjectPigscriptTask):
    """
    This is a Luigi Task that extends MortarProjectPigscriptTask to run a Pig
    script on Mortar.
    """

    """
    The location in S3 where the output of the Mortar job will be written.
    """
    output_base_path = luigi.Parameter() 

    """
    Default cluster size to use for running Mortar jobs.  A cluster size of 0
    will run in Mortar's local mode.  This is a fast (and free!) way to run jobs
    on small data samples.  Cluster sizes >= 2 will run on a Hadoop cluster.
    """
    cluster_size = luigi.IntParameter(default=0)

    """
    Path to input data being analyzed using the Pig script.
    """
    input_path = luigi.Parameter(default ='s3://mortar-example-data/tutorial/excite.log.bz2')


    def requires(self):
        """
        The requires method specifies a list of other Tasks that must be complete
        for this Task to run. In this case, we want to require that our input
        exists on S3 before we run the script. S3PathTask validates that the
        specified file or directory exists on S3.
        """
        return [S3PathTask(self.input_path)]

    def project(self):
        """
        Name of Mortar Project to run.
        """
        return MORTAR_PROJECT

    def script_output(self):
        """
        The script_output method is how you define where the output from this task
        will be stored. Luigi will check this output location before starting any
        tasks that depend on this task.
        """
        return[S3Target(self.output_base_path + '/pigoutput')]

    def token_path(self):
        """
        Luigi manages dependencies between tasks by checking for the existence of
        files.  When one task finishes it writes out a 'token' file that will
        trigger the next task in the dependency graph.  This is the base path for
        where those tokens will be written.
        """
        return self.output_base_path

    def parameters(self):
        """
        Parameters for this pig job.
        """
        return {'INPUT_PATH': self.input_path,
            'OUTPUT_PATH': self.output_base_path + '/pigoutput'}

    def script(self):
        """
        Name of Pig script to run.
        """
        return '<%= project_name %>'


class ShutdownClusters(mortartask.MortarClusterShutdownTask):
    """
    When the pipeline is completed, this task shuts down all active clusters not
    currently running jobs. As this task is only shutting down clusters and not
    generating any output data, this S3 location is used to store a 'token' file
    indicating when the task has been completed.
    """
    output_base_path = luigi.Parameter() 

    """
    This is an example of using the Mortar logger.
    """
    LOGGER.info('My Log Message!')

    def requires(self):
        """
        The ShutdownClusters task is dependent on RunMyExamplePigScript because a
        cluster should not shut down until all the tasks are completed. You can
        think of this as saying 'shut down my cluster after running my task'.
        """
        return RunMyExamplePigScript(output_base_path = self.output_base_path)

    def output(self):
        """
        This output statement is needed because ShutdownClusters has no actual
        output. We write a token with the class name to S3 to know that this task
        has completed and it does not need to be run again.
        """
        return [S3Target((create_full_path(self.output_base_path, 'ShutdownClusters')))]

if __name__ == "__main__":
    """
    The final task in your pipeline, which will in turn pull in any dependencies
    need to be run should be called in the main method. In this case ShutdownClusters
    is being called.
    """
    luigi.run(main_task_cls= ShutdownClusters)
