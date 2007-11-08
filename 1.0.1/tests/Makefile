MODULEPATH=libexec/httpd
CHECKOUT=

all:	startup.pl httpd.conf logs
	@echo "'make run' to start on port 8989"

run:
	httpd -X -f `pwd`/httpd.conf

logs:
	@echo "Creating logs dir"
	@mkdir -p logs

clean:
	rm -f startup.pl httpd.conf

startup.pl:	startup.pl.in
	@echo "Creating startup.pl"
	@if test -z "${CHECKOUT}"; then \
	sed -e "s^@@CHECKOUT@@^"`pwd`"/..^g;" \
		-e "s^@@MODULEPATH@@^${MODULEPATH}^g;" < \
		startup.pl.in > \
		startup.pl ; \
	else \
	sed -e "s^@@CHECKOUT@@^${CHECKOUT}^g;" \
		-e "s^@@MODULEPATH@@^${MODULEPATH}^g;" < \
		startup.pl.in > \
		startup.pl ; \
	fi

httpd.conf:	httpd.conf.in
	@echo "Creating httpd.conf (LoadModule lines might need fixup)"
	@if test -z "${CHECKOUT}"; then \
	sed -e "s^@@CHECKOUT@@^"`pwd`"/..^g;" \
		-e "s^@@MODULEPATH@@^${MODULEPATH}^g;" < \
		httpd.conf.in > \
		httpd.conf ; \
	else \
	sed -e "s^@@CHECKOUT@@^${CHECKOUT}^g;" \
		-e "s^@@MODULEPATH@@^${MODULEPATH}^g;" < \
		httpd.conf.in > \
		httpd.conf ; \
	fi
