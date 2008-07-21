MODULEPATH=libexec/httpd
MODULEPATH2=libexec/apache2
CHECKOUT=

all:	startup.pl httpd.conf httpd2.conf logs
	@echo "'make run' to start Apache1 on port 8989"
	@echo "'make run2' to start on Apache2 port 8989"

run:
	httpd -X -f `pwd`/httpd.conf

run2:
	httpd -f `pwd`/httpd2.conf -k start
	@echo "'make stop2' to stop Apache2"

stop2:
	httpd -f `pwd`/httpd2.conf -k stop

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

httpd2.conf:	httpd2.conf.in
	@echo "Creating httpd2.conf (LoadModule lines might need fixup)"
	@if test -z "${CHECKOUT}"; then \
	sed -e "s^@@CHECKOUT@@^"`pwd`"/..^g;" \
		-e "s^@@MODULEPATH@@^${MODULEPATH2}^g;" < \
		httpd2.conf.in > \
		httpd2.conf ; \
	else \
	sed -e "s^@@CHECKOUT@@^${CHECKOUT}^g;" \
		-e "s^@@MODULEPATH@@^${MODULEPATH2}^g;" < \
		httpd2.conf.in > \
		httpd2.conf ; \
	fi
