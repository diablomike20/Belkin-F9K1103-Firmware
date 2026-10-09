$("form").submit(function(e){
	e.preventDefault();

	const $form = $(this);
	$("button[type='submit']").prop("disabled", true);

	let passwordValue = '';
	const $activePwd = get_password_input();
	if ($activePwd) {
		passwordValue = $activePwd.val();
	}

	// F9K1103 port intentionally uses LEDE's native password verifier.
	// No Cudy crypt helper, salt or one-time-token transform is required.
	$("input[name='luci_password']").val(passwordValue);
	$("input[name='zonename']").val(Intl.DateTimeFormat().resolvedOptions().timeZone);
	$("input[name='timeclock']").val(Math.floor((new Date()).getTime() / 1000));

	$form[0].submit();
});

$(document).ready(function() {
	$('#cbi-modal-auth').on('shown.bs.modal', function () {
		const $activePwd = get_password_input();
		$activePwd && $activePwd.focus();
	});

	$.get("/cgi-bin/luci/admin/logout");
	setCookie("ignoreUpdate", "", {'max-age': -1});
	$('#cbi-create-password').css('padding', '25px');
	$('#cbi-create-password-tips').css({'margin-left':'-25px', 'color':'#777'});
	$('#cbi-modal-auth').modal({backdrop: 'static', keyboard: false});
});

function get_password_input() {
	const $loginPwd = $('#luci_password_login, #luci_password2').first();
	const $createPwd = $('#luci_password_create');

	if ($loginPwd.length > 0) {
		return $loginPwd;
	} else if ($createPwd.length > 0) {
		return $createPwd;
	}
	return null;
}

function sysauth_check_password(pwd) {
	setTimeout(function() {
		if ((pwd.value.length < 8) || (pwd.value.length > 64)) {
			$(pwd).parent().addClass("has-error");
			$("button[type=submit]").prop("disabled", true);
		} else {
			$(pwd).parent().removeClass("has-error");
			$("button[type=submit]").prop("disabled", false);
		}
	}, 0);
}
