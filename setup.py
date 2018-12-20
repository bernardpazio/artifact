from distutils.core import setup, Extension
from distutils.command.sdist import sdist as _sdist

try:
    from Cython.Distutils import build_ext
except ImportError:
    use_cython = False
else:
    use_cython = True

cmdclass = {}
ext_modules = []

if use_cython:
    ext_modules += [
        Extension("artifact.adc", ["adc.pyx"]),
        Extension("artifact.cards", ['cards.pyx'])
    ]
    cmdclass['build_ext'] = build_ext

    class sdist(_sdist):
        def run(self):
            from Cython.Build import cythonize
            cythonize(['adc.pyx', 'cards.pyx'])
            _sdist.run(self)

    cmdclass['sdist'] = sdist
else:
    ext_modules += [
        Extension("artifact.adc", ["adc.c"]),
        Extension("artifact.card", ["card.c"])
    ]

setup(
    cmdclass=cmdclass,
    ext_modules=ext_modules,
    name='artifact',
    version='0.1',
    description="A wrapper for Artifacts Card API with a python implementation of their deck code encoder/decoder",
    url='https://github.com/bernardpazio/artifact',
    author='Bernard Pazio',
    author_email='bernardpazio@gmail.com',
    install_requires=['requests']
)