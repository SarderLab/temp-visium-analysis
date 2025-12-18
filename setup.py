#! /usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

from setuptools import find_packages, setup


def prerelease_local_scheme(version):
    """
    Return local scheme version unless building on master in CircleCI.

    This function returns the local scheme version number
    (e.g. 0.0.0.dev<N>+g<HASH>) unless building on CircleCI for a
    pre-release in which case it ignores the hash and produces a
    PEP440 compliant pre-release version number (e.g. 0.0.0.dev<N>).
    """
    from setuptools_scm.version import get_local_node_and_date

    if os.getenv('CIRCLE_BRANCH') in {'master'}:
        return ''
    else:
        return get_local_node_and_date(version)


setup(
    name='visium_processing',
    use_scm_version={'local_scheme': prerelease_local_scheme},
    description='Plugin for label transfer, cell deconvolution and generating 10x Visium spot annotations',
    long_description='',
    long_description_content_type='text/x-rst',
    author='Anish Tatke',
    author_email='anish.tatke@medicine.ufl.edu',
    url='https://github.com/SarderLab/Spatial-Omics-Plugins/general',
    packages=find_packages(exclude=['tests', '*_test']),
    package_dir={
        'visium_processing': 'visium-processing',
    },
    include_package_data=True,
    install_requires=[
        # scientific packages
        'girder-slicer-cli-web',
        'girder-client',
        'fusion-tools>=3.6.88',
        'ctk-cli',
    ],
    license='Apache Software License 2.0',
    keywords='visium_processing',
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'License :: OSI Approved :: Apache Software License',
        'Programming Language :: Python :: 3.12',
        'Topic :: Scientific/Engineering :: Artificial Intelligence',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ],
    zip_safe=False,
)